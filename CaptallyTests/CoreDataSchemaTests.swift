import CoreData
import XCTest
@testable import Captally

/// Guards the model version chain: Captally ships a real V1 -> V2 -> V3 history rather than a
/// single bare model, and each delta (provenance columns added and Member/SplitRecord removed in
/// V2, the device-local capture tables added in V3) must upgrade a live store without a custom
/// mapping model.
///
/// Loading a second copy of the model in-process makes Core Data log "failed to find a unique
/// match for an NSEntityDescription" for the shared classes. That log is expected here and is the
/// price of testing a migration in the same process as the running app; fetches still resolve
/// through each context's own coordinator.
///
/// Entity syncability (`syncable="NO"` on the two capture tables) has no public accessor on
/// `NSEntityDescription`, so it is checked in the model source rather than from a test.
@MainActor
final class CoreDataSchemaTests: XCTestCase {
    private var storeDirectory: URL!

    override func setUpWithError() throws {
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptallySchemaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeDirectory)
        storeDirectory = nil
    }

    func testModelBundleCarriesEveryVersion() throws {
        let versions = try Self.modelVersions()
        XCTAssertEqual(Set(versions), ["CaptallyV1", "CaptallyV2", "CaptallyV3"])
    }

    func testV2DropsTheSharedLedgerSubsystem() throws {
        let v1 = try Self.model(named: "CaptallyV1")
        let v2 = try Self.model(named: "CaptallyV2")

        XCTAssertEqual(Set(v2.entities.compactMap(\.name)), Self.ledgerEntities)
        XCTAssertTrue(Set(v1.entities.compactMap(\.name)).contains("Member"))
        for version in ["CaptallyV2", "CaptallyV3"] {
            let model = try Self.model(named: version)
            XCTAssertNil(model.entitiesByName["Member"], "\(version) still ships Member")
            XCTAssertNil(model.entitiesByName["SplitRecord"], "\(version) still ships SplitRecord")
        }

        let bookAttributes = Set(v2.entitiesByName["Book"]?.properties.compactMap { ($0 as? NSAttributeDescription)?.name } ?? [])
        XCTAssertFalse(bookAttributes.contains("type"))

        let bookRelationships = Set(v2.entitiesByName["Book"]?.properties.compactMap {
            ($0 as? NSRelationshipDescription)?.name
        } ?? [])
        XCTAssertFalse(bookRelationships.contains("members"))
    }

    func testV3AddsTheDeviceLocalCaptureTables() throws {
        let v2 = try Self.model(named: "CaptallyV2")
        let v3 = try Self.model(named: "CaptallyV3")

        XCTAssertNil(v2.entitiesByName["ProcessedAsset"])
        XCTAssertNil(v2.entitiesByName["ScanBatch"])
        XCTAssertEqual(Set(v3.entities.compactMap(\.name)), Self.ledgerEntities.union(["ProcessedAsset", "ScanBatch"]))

        XCTAssertEqual(attributes(of: "ProcessedAsset", in: v3), [
            "assetIdentifier", "assetCreationDate", "batchID", "firstSeenAt", "lastScannedAt", "outcome", "retryCount",
        ])
        XCTAssertEqual(attributes(of: "ScanBatch", in: v3), [
            "finishedAt", "id", "scannedCount", "startedAt", "status",
        ])
        // Capture state hangs off nothing: it must never reach into the synced ledger.
        for name in ["ProcessedAsset", "ScanBatch"] {
            let relationships = v3.entitiesByName[name]?.properties.compactMap {
                $0 as? NSRelationshipDescription
            } ?? []
            XCTAssertTrue(relationships.isEmpty, name)
        }
    }

    func testV2TransactionCarriesCaptureProvenance() throws {
        let v2 = try Self.model(named: "CaptallyV2")
        let attributes = Set(v2.entitiesByName["Transaction"]?.properties.compactMap { ($0 as? NSAttributeDescription)?.name } ?? [])
        let expected: Set<String> = [
            "merchantRaw", "merchantNormalized", "orderNumber", "transactionNumber", "source",
            "sourcePlatform", "paymentMethod", "sourceAssetIdentifier", "ocrConfidence",
            "parserConfidence", "semanticConfidence", "finalConfidence", "reviewStatus",
            "dedupFingerprint", "originalTransactionID", "parserVersion", "aiProvider",
            "modelVersion", "estimatedDate", "createdAt", "updatedAt",
        ]
        XCTAssertNil(try Self.model(named: "CaptallyV1").entitiesByName["Transaction"]?.attributesByName["dedupFingerprint"])
        XCTAssertTrue(expected.isSubset(of: attributes), "missing \(expected.subtracting(attributes))")
    }

    func testEveryAttributeIsOptionalOrDefaultedForCloudKit() throws {
        // CloudKit refuses to provision a store whose attributes are required without a default.
        for version in ["CaptallyV2", "CaptallyV3"] {
            let model = try Self.model(named: version)
            for entity in model.entities {
                for attribute in entity.properties.compactMap({ $0 as? NSAttributeDescription }) {
                    let satisfied = attribute.isOptional
                        || attribute.defaultValue != nil
                        || attribute.renamingIdentifier != nil
                    XCTAssertTrue(
                        satisfied,
                        "\(version): \(entity.name ?? "?").\(attribute.name) is required and has no default"
                    )
                }
            }
        }
    }

    func testV2StoreUpgradesToV3AndKeepsItsRows() throws {
        let storeURL = storeDirectory.appendingPathComponent("capture-columns.sqlite")
        let transactionID = UUID()

        let v2Coordinator = NSPersistentStoreCoordinator(managedObjectModel: try Self.model(named: "CaptallyV2"))
        let v2Store = try v2Coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        let v2Context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        v2Context.persistentStoreCoordinator = v2Coordinator
        let book = NSEntityDescription.insertNewObject(forEntityName: "Book", into: v2Context)
        book.setValue(UUID(), forKey: "id")
        book.setValue("Daily", forKey: "name")
        book.setValue(Date(timeIntervalSince1970: 1_700_000_000), forKey: "createdAt")
        let transaction = NSEntityDescription.insertNewObject(forEntityName: "Transaction", into: v2Context)
        transaction.setValue(transactionID, forKey: "id")
        transaction.setValue(NSDecimalNumber(decimal: 12.5), forKey: "amount")
        transaction.setValue(Date(timeIntervalSince1970: 1_700_000_001), forKey: "date")
        transaction.setValue(book, forKey: "book")
        try v2Context.save()
        try v2Coordinator.remove(v2Store)

        let v3Coordinator = NSPersistentStoreCoordinator(managedObjectModel: try Self.model(named: "CaptallyV3"))
        _ = try v3Coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
            ]
        )
        let v3Context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        v3Context.persistentStoreCoordinator = v3Coordinator

        XCTAssertEqual(
            try v3Context.fetch(NSFetchRequest<Transaction>(entityName: "Transaction")).map(\.id),
            [transactionID]
        )
        // The two new tables arrive empty; they are the only thing V3 added.
        XCTAssertEqual(try v3Context.count(for: NSFetchRequest<ProcessedAsset>(entityName: "ProcessedAsset")), 0)
        XCTAssertEqual(try v3Context.count(for: NSFetchRequest<ScanBatch>(entityName: "ScanBatch")), 0)
    }

    func testV1StoreUpgradesToV2AndKeepsItsRows() throws {
        let storeURL = storeDirectory.appendingPathComponent("captally.sqlite")
        let transactionID = UUID()
        let bookID = UUID()

        // Phase 1: a store written by the schema that shipped before Captally existed.
        let v1Model = try Self.model(named: "CaptallyV1")
        // V1 made a member mandatory for every transaction; those classes are gone, so the
        // fixture rows are built as plain managed objects.
        for gone in ["Member", "SplitRecord"] {
            v1Model.entitiesByName[gone]?.managedObjectClassName = nil
        }
        let v1Coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1Model)
        let v1Store = try v1Coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        let v1Context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        v1Context.persistentStoreCoordinator = v1Coordinator

        let book = NSEntityDescription.insertNewObject(forEntityName: "Book", into: v1Context)
        book.setValue(bookID, forKey: "id")
        book.setValue("Upstream ledger", forKey: "name")
        book.setValue(Date(timeIntervalSince1970: 1_600_000_000), forKey: "createdAt")

        let category = NSEntityDescription.insertNewObject(forEntityName: "Category", into: v1Context)
        category.setValue(UUID(), forKey: "id")
        category.setValue("餐饮", forKey: "name")
        category.setValue(book, forKey: "book")

        let member = NSEntityDescription.insertNewObject(forEntityName: "Member", into: v1Context)
        member.setValue(UUID(), forKey: "id")
        member.setValue("我", forKey: "name")
        member.setValue(Date(timeIntervalSince1970: 1_600_000_000), forKey: "joinedAt")
        member.setValue(book, forKey: "book")

        let transaction = NSEntityDescription.insertNewObject(forEntityName: "Transaction", into: v1Context)
        transaction.setValue(transactionID, forKey: "id")
        transaction.setValue(NSDecimalNumber(decimal: 42_567), forKey: "amount")
        transaction.setValue(Date(timeIntervalSince1970: 1_600_000_001), forKey: "date")
        transaction.setValue(Date(timeIntervalSince1970: 1_600_000_001), forKey: "createdAt")
        transaction.setValue(Date(timeIntervalSince1970: 1_600_000_001), forKey: "updatedAt")
        transaction.setValue(book, forKey: "book")
        transaction.setValue(category, forKey: "category")
        transaction.setValue(member, forKey: "member")
        try v1Context.save()
        try v1Coordinator.remove(v1Store)

        // Phase 2: the same file opened by the current model, lightweight migration only.
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path), "V1 store disappeared")
        let v2Coordinator = NSPersistentStoreCoordinator(managedObjectModel: try Self.model(named: "CaptallyV2"))
        _ = try v2Coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
            ]
        )

        let v2Context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        v2Context.persistentStoreCoordinator = v2Coordinator

        let migrated = try XCTUnwrap(
            v2Context.fetch(NSFetchRequest<Transaction>(entityName: "Transaction")).first
        )
        XCTAssertEqual(migrated.id, transactionID)
        XCTAssertEqual(migrated.amount as Decimal, 42_567)
        XCTAssertEqual(migrated.book?.id, bookID)
        XCTAssertEqual(migrated.category?.name, "餐饮")
        XCTAssertEqual(migrated.transactionType, .expense)
        // Provenance columns arrive unset rather than backfilled, and the enum wrappers fall back.
        XCTAssertEqual(migrated.transactionSource, .manual)
        XCTAssertEqual(migrated.currentReviewStatus, .userConfirmed)
        XCTAssertEqual(migrated.platform, .generic)
        XCTAssertNil(migrated.dedupFingerprint)
        XCTAssertEqual(try v2Context.count(for: NSFetchRequest<Book>(entityName: "Book")), 1)
    }

    // MARK: - Helpers

    private static let ledgerEntities: Set<String> = [
        "Account", "Book", "Budget", "Category", "Transaction",
    ]

    private func attributes(of entityName: String, in model: NSManagedObjectModel) -> Set<String> {
        let properties = model.entitiesByName[entityName]?.properties ?? []
        return Set(properties.compactMap { ($0 as? NSAttributeDescription)?.name })
    }

    private static func model(named version: String) throws -> NSManagedObjectModel {
        let momd = try XCTUnwrap(
            Bundle.main.url(forResource: "Captally", withExtension: "momd"),
            "Captally.momd is missing from the host app bundle"
        )
        let url = momd.appendingPathComponent("\(version).mom")
        return try XCTUnwrap(
            NSManagedObjectModel(contentsOf: url),
            "could not load model version \(version)"
        )
    }

    private static func modelVersions() throws -> [String] {
        let momd = try XCTUnwrap(Bundle.main.url(forResource: "Captally", withExtension: "momd"))
        return try FileManager.default.contentsOfDirectory(atPath: momd.path)
            .filter { $0.hasSuffix(".mom") }
            .map { String($0.dropLast(4)) }
    }
}
