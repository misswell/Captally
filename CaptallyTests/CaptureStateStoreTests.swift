import CoreData
import XCTest
@testable import Captally

/// The capture store is the only thing standing between an incremental scan and a duplicate
/// expense, so its verdict rules are pinned here: registered means pending, a verdict means
/// settled, and a failing screenshot stops being retried once its budget is gone.
@MainActor
final class CaptureStateStoreTests: XCTestCase {
    private var persistence: PersistenceController!
    private var store: CoreDataCaptureStateStore!

    private let older = ScreenshotAssetInfo(identifier: "OLD/1", creationDate: Date(timeIntervalSince1970: 1_600_000_000))
    private let newer = ScreenshotAssetInfo(identifier: "NEW/1", creationDate: Date(timeIntervalSince1970: 1_700_000_000))

    override func setUp() {
        persistence = PersistenceController(inMemory: true)
        store = CoreDataCaptureStateStore(persistence: persistence)
    }

    override func tearDown() {
        store = nil
        persistence = nil
    }

    func testRegisteredAssetsWaitForAVerdict() async {
        await store.register([older, newer], batchID: UUID())

        let count = await store.processedCount()
        let settled = await store.settledIdentifiers(maxRetries: 3)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(settled, [])
    }

    func testEveryTerminalVerdictSettlesAnAsset() async {
        let terminal = AssetScanOutcome.allCases.filter(\.isTerminal)
        XCTAssertFalse(terminal.isEmpty)

        for (offset, outcome) in terminal.enumerated() {
            let asset = ScreenshotAssetInfo(
                identifier: "asset-\(offset)",
                creationDate: Date(timeIntervalSince1970: 1_600_000_000 + Double(offset))
            )
            await store.register([asset], batchID: UUID())
            await store.setOutcome(outcome, for: asset.identifier)

            let settled = await store.settledIdentifiers(maxRetries: 3)
            XCTAssertTrue(
                settled.contains(asset.identifier),
                "\(outcome.rawValue) must never be read again"
            )
        }
    }

    func testFailuresAreRetriedUpToTheBudgetAndThenSettle() async {
        await store.register([newer], batchID: UUID())

        await store.setOutcome(.failed, for: newer.identifier)
        var settled = await store.settledIdentifiers(maxRetries: 2)
        XCTAssertEqual(row(withIdentifier: newer.identifier)?.retryCount, 1)
        XCTAssertFalse(settled.contains(newer.identifier), "the first failure still has budget left")

        await store.setOutcome(.failed, for: newer.identifier)
        settled = await store.settledIdentifiers(maxRetries: 2)
        XCTAssertEqual(row(withIdentifier: newer.identifier)?.retryCount, 2)
        XCTAssertTrue(settled.contains(newer.identifier))
    }

    func testReRegisteringAKnownAssetKeepsOneRowAndItsFirstBatch() async {
        let firstBatch = UUID()
        await store.register([newer], batchID: firstBatch)
        await store.register([newer], batchID: UUID())

        let count = await store.processedCount()
        XCTAssertEqual(count, 1)
        XCTAssertEqual(row(withIdentifier: newer.identifier)?.batchID, firstBatch)
    }

    func testBatchRecordsHowManyScreenshotsItScanned() async {
        let batchID = await store.beginBatch()
        await store.register([older, newer], batchID: batchID)
        await store.endBatch(batchID, status: .completed, scannedCount: 2)

        let batch = batch(withIdentifier: batchID)
        XCTAssertEqual(batch?.batchStatus, .completed)
        XCTAssertEqual(batch?.scannedCount, 2)
        XCTAssertNotNil(batch?.finishedAt)
    }

    func testAVerdictForAnUnknownAssetChangesNothing() async {
        await store.setOutcome(.paymentFound, for: "never-seen")
        let count = await store.processedCount()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Helpers

    private func row(withIdentifier identifier: String) -> ProcessedAsset? {
        let request = NSFetchRequest<ProcessedAsset>(entityName: "ProcessedAsset")
        request.predicate = NSPredicate(format: "assetIdentifier == %@", identifier)
        request.sortDescriptors = [NSSortDescriptor(key: "assetCreationDate", ascending: true)]
        return try? persistence.viewContext.fetch(request).first
    }

    private func batch(withIdentifier id: UUID) -> ScanBatch? {
        let request = NSFetchRequest<ScanBatch>(entityName: "ScanBatch")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? persistence.viewContext.fetch(request).first
    }
}
