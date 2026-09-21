import CoreData
import XCTest
@testable import Captally

/// Stage 1 exit criteria, executable: a fresh install writes nothing, the CloudKit container has
/// exactly one source, and the permission strings the app actually needs are present.
@MainActor
final class StageOneAcceptanceTests: XCTestCase {
    func testFreshStoreContainsNoSyntheticTransactions() throws {
        let environment = AppEnvironment.ephemeral()
        let context = environment.persistence.viewContext
        let count = try context.count(for: NSFetchRequest<Transaction>(entityName: "Transaction"))
        XCTAssertEqual(count, 0)
    }

    func testAutoSeedingIsOffWithoutTheExplicitOptIn() throws {
        XCTAssertNil(
            ProcessInfo.processInfo.environment[DemoDataSeeder.environmentKey],
            "the test runner must not inherit \(DemoDataSeeder.environmentKey)=1"
        )
        XCTAssertFalse(DemoDataSeeder.isAutoSeedAllowed)

        let environment = AppEnvironment.ephemeral()
        DemoDataSeeder.seedIfNeeded(using: environment.persistence)
        let count = try environment.persistence.viewContext.count(
            for: NSFetchRequest<Transaction>(entityName: "Transaction")
        )
        XCTAssertEqual(count, 0)
    }

    func testManualSeedingStillWorks() throws {
        let environment = AppEnvironment.ephemeral()
        let created = DemoDataSeeder.seed(using: environment.persistence, days: 7)
        XCTAssertGreaterThan(created, 0)
        XCTAssertEqual(
            try environment.persistence.viewContext.count(for: NSFetchRequest<Transaction>(entityName: "Transaction")),
            created
        )
    }

    func testCloudKitContainerResolvesFromInfoPlist() {
        XCTAssertEqual(CaptallyConfiguration.cloudKitContainerIdentifier, "iCloud.com.misswell.Captally")
    }

    /// The ported ledger view models still write through `PersistenceController.shared`, so the
    /// injected environment must point at that same container or the ledger splits in two.
    func testEnvironmentSharesTheOnePersistentStoreCoordinator() {
        XCTAssertTrue(AppEnvironment().persistence === PersistenceController.shared)
    }

    func testPhotoLibraryPermissionIsDeclaredAndCloudKitIsNotAPrompt() {
        let info = Bundle.main.infoDictionary ?? [:]
        let usage = info["NSPhotoLibraryUsageDescription"] as? String
        XCTAssertNotNil(usage)
        XCTAssertFalse(usage?.isEmpty ?? true)
        // A screenshot app reads, it never writes back, so Add-Photos access must stay unclaimed.
        XCTAssertNil(info["NSPhotoLibraryAddUsageDescription"])
        XCTAssertNil(info["NSCloudKitUsageDescription"], "not a real Info.plist key")
        XCTAssertNil(info["CKSharingSupported"], "shared ledgers were removed")
    }
}
