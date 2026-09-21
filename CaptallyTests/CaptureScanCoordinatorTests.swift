import CoreData
import XCTest
@testable import Captally

/// Stage 2 exit criteria, executable: a pass finds the new screenshots, an already settled
/// screenshot is never read again, and none of that depends on in-memory state, so a relaunch
/// resumes from the same place.
@MainActor
final class CaptureScanCoordinatorTests: XCTestCase {
    private var storeDirectory: URL!
    private var provider: FakeScreenshotLibrary!
    private var understanding: FakeUnderstanding!

    private static let day: TimeInterval = 24 * 60 * 60
    private static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptallyCaptureTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        provider = FakeScreenshotLibrary()
        understanding = FakeUnderstanding()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storeDirectory)
        storeDirectory = nil
        provider = nil
        understanding = nil
    }

    // MARK: - Discovery

    func testFirstPassReadsEveryScreenshotOldestFirst() async {
        await provider.add([screenshot("c", daysAgo: 2), screenshot("a", daysAgo: 6), screenshot("b", daysAgo: 4)])
        let stack = makeStack()

        let report = await stack.coordinator.scan()

        XCTAssertEqual(report.discovered.map(\.identifier), ["a", "b", "c"], "oldest first, whatever order PhotoKit returns")
        XCTAssertEqual(report.libraryCount, 3)
        XCTAssertEqual(report.alreadyKnownCount, 0)
        XCTAssertNil(report.skipped)
        XCTAssertNotNil(report.batchID)
    }

    func testSettledScreenshotsAreNeverReadAgain() async {
        await provider.add([screenshot("a", daysAgo: 1), screenshot("b", daysAgo: 2)])
        let stack = makeStack()

        let first = await stack.coordinator.scan()
        let second = await stack.coordinator.scan()
        let reads = await understanding.reads

        XCTAssertEqual(first.discovered.count, 2)
        XCTAssertEqual(second.discovered, [])
        XCTAssertEqual(second.alreadyKnownCount, 2)
        XCTAssertNil(second.batchID)
        XCTAssertEqual(reads, ["b", "a"])
    }

    func testOnlyNewScreenshotsAreDiscovered() async {
        let stack = makeStack()
        await provider.add([screenshot("a", daysAgo: 3)])
        _ = await stack.coordinator.scan()

        await provider.add([screenshot("b", daysAgo: 1), screenshot("c", daysAgo: 2)])
        let report = await stack.coordinator.scan()
        let reads = await understanding.reads

        XCTAssertEqual(report.discovered.map(\.identifier), ["c", "b"])
        XCTAssertEqual(report.alreadyKnownCount, 1)
        XCTAssertEqual(reads.count, 3)
    }

    func testARedatedScreenshotIsNotReadTwice() async {
        await provider.add([screenshot("a", daysAgo: 5)])
        let stack = makeStack()
        _ = await stack.coordinator.scan()

        // PhotoKit re-stamps an asset after an iCloud merge; the identifier is the only anchor.
        await provider.replace([screenshot("a", daysAgo: 0)])
        let report = await stack.coordinator.scan()
        let reads = await understanding.reads

        XCTAssertEqual(report.discovered, [])
        XCTAssertEqual(reads.count, 1)
    }

    // MARK: - Retries

    func testUnfinishedScreenshotIsReadAgainOnTheNextPass() async {
        await understanding.setFallback(.pending)
        await provider.add([screenshot("a", daysAgo: 1)])
        let stack = makeStack()

        let first = await stack.coordinator.scan()
        let second = await stack.coordinator.scan()
        let reads = await understanding.reads

        XCTAssertEqual(first.discovered.count, 1)
        XCTAssertEqual(second.discovered.map(\.identifier), ["a"], "a pass that never reached a verdict must not strand the asset")
        XCTAssertEqual(reads.count, 2)
    }

    func testFailuresStopBeingRetriedOnceTheBudgetIsSpent() async {
        await understanding.setFallback(.failed)
        await provider.add([screenshot("a", daysAgo: 1)])
        let stack = makeStack()

        var discoveredPerPass: [Int] = []
        for _ in 0..<(ScreenshotScanCoordinator.maxRetries + 3) {
            discoveredPerPass.append(await stack.coordinator.scan().discovered.count)
        }

        let budget = ScreenshotScanCoordinator.maxRetries
        XCTAssertEqual(Array(discoveredPerPass.prefix(budget)), [Int](repeating: 1, count: budget))
        XCTAssertEqual(Array(discoveredPerPass.suffix(3)), [0, 0, 0], "a permanently unreadable screenshot cannot spin forever")
    }

    func testConcurrentPassesDoNotReadTheSameScreenshotTwice() async {
        await provider.add([screenshot("a", daysAgo: 1), screenshot("b", daysAgo: 2)])
        let stack = makeStack()

        async let first = stack.coordinator.scan()
        async let second = stack.coordinator.scan()
        let early = await first
        let late = await second
        let reads = await understanding.reads

        // Whether the second caller joined the running pass or ran after it, the work happens once.
        XCTAssertEqual(early.libraryCount, 2)
        XCTAssertEqual(late.libraryCount, 2)
        XCTAssertEqual(early.discovered.count, 2)
        XCTAssertEqual(reads.count, 2)
    }

    // MARK: - Access and failures

    func testPassWithoutLibraryAccessDoesNoWork() async {
        await provider.add([screenshot("a", daysAgo: 1)])
        await provider.setAccess(.denied)
        let stack = makeStack()

        let report = await stack.coordinator.scan()
        let status = await stack.coordinator.currentAccessStatus()
        let reads = await understanding.reads
        let registered = await stack.stateStore.processedCount()

        XCTAssertEqual(report.skipped, .accessDenied)
        XCTAssertEqual(status, .denied)
        XCTAssertTrue(reads.isEmpty)
        XCTAssertEqual(registered, 0, "a denied pass must not register anything")
    }

    func testUnavailableLibraryIsReportedAndLeftForTheNextPass() async {
        await provider.add([screenshot("a", daysAgo: 1)])
        await provider.setEnumerationFails(true)
        let stack = makeStack()

        let unavailable = await stack.coordinator.scan()
        await provider.setEnumerationFails(false)
        let recovered = await stack.coordinator.scan()

        XCTAssertEqual(unavailable.skipped, .libraryUnavailable)
        XCTAssertTrue(unavailable.discovered.isEmpty)
        XCTAssertEqual(recovered.discovered.map(\.identifier), ["a"])
    }

    // MARK: - Restart

    func testScanStateSurvivesARelaunch() async throws {
        let storeURL = storeDirectory.appendingPathComponent("capture.sqlite")
        await provider.add([screenshot("a", daysAgo: 2), screenshot("b", daysAgo: 1)])

        // Launch 1.
        let firstLaunch = makeStack(storeURL: storeURL)
        let firstReport = await firstLaunch.coordinator.scan()
        XCTAssertEqual(firstReport.discovered.count, 2)
        try close(firstLaunch.persistence)

        // Launch 2: a fresh container over the same file, which is what a relaunch really is.
        let secondLaunch = makeStack(storeURL: storeURL)
        let secondReport = await secondLaunch.coordinator.scan()
        let storedCount = await secondLaunch.stateStore.processedCount()
        let reads = await understanding.reads
        try close(secondLaunch.persistence)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertEqual(secondReport.discovered, [], "restart must not re-read settled screenshots")
        XCTAssertEqual(secondReport.alreadyKnownCount, 2)
        XCTAssertEqual(storedCount, 2)
        XCTAssertEqual(reads.count, 2)
    }

    func testAScreenshotWithoutAVerdictIsFoundAgainAfterARelaunch() async throws {
        let storeURL = storeDirectory.appendingPathComponent("interrupted.sqlite")
        await provider.add([screenshot("a", daysAgo: 2), screenshot("b", daysAgo: 1)])
        await understanding.setFallback(.pending)

        let firstLaunch = makeStack(storeURL: storeURL)
        let firstReport = await firstLaunch.coordinator.scan()
        try close(firstLaunch.persistence)

        await understanding.setFallback(.paymentFound)
        let secondLaunch = makeStack(storeURL: storeURL)
        let secondReport = await secondLaunch.coordinator.scan()
        let storedCount = await secondLaunch.stateStore.processedCount()
        try close(secondLaunch.persistence)

        XCTAssertEqual(firstReport.discovered.count, 2)
        XCTAssertEqual(secondReport.discovered.count, 2, "registration alone is not a verdict")
        XCTAssertEqual(storedCount, 2)
    }

    // MARK: - Composition root

    func testPipelinePublishesWhatThePassFound() async {
        await provider.add([screenshot("a", daysAgo: 1)])
        let stack = makeStack()
        let pipeline = CaptallyPipeline(provider: provider, state: stack.stateStore)

        let report = await pipeline.scanNow()

        XCTAssertEqual(report.discovered.map(\.identifier), ["a"])
        XCTAssertEqual(pipeline.lastReport, report)
        XCTAssertEqual(pipeline.accessStatus, .granted)
        XCTAssertFalse(pipeline.isScanning)
    }

    // MARK: - Stack

    private struct Stack {
        let persistence: PersistenceController
        let stateStore: CoreDataCaptureStateStore
        let coordinator: ScreenshotScanCoordinator
    }

    private func makeStack(storeURL: URL? = nil) -> Stack {
        let persistence = storeURL.map { PersistenceController(inMemory: false, storeURL: $0) }
            ?? PersistenceController(inMemory: true)
        let stateStore = CoreDataCaptureStateStore(persistence: persistence)
        return Stack(
            persistence: persistence,
            stateStore: stateStore,
            coordinator: ScreenshotScanCoordinator(
                provider: provider,
                state: stateStore,
                understanding: understanding
            )
        )
    }

    /// Closes the SQLite file so the next stack can open it without a store lock.
    private func close(_ persistence: PersistenceController) throws {
        let coordinator = persistence.container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }

    private func screenshot(_ identifier: String, daysAgo: Double) -> ScreenshotAssetInfo {
        ScreenshotAssetInfo(
            identifier: identifier,
            creationDate: Self.epoch.addingTimeInterval(-daysAgo * Self.day)
        )
    }
}

// MARK: - Fakes

/// A stand-in for the screenshot album. The scan rules have to be provable without a photo
/// library, because a duplicate read is a duplicate expense.
private actor FakeScreenshotLibrary: ScreenshotAssetProviding {
    private var access: ScreenshotAccessStatus = .granted
    private var assets: [ScreenshotAssetInfo] = []
    private var enumerationFails = false

    func setAccess(_ status: ScreenshotAccessStatus) { access = status }
    func setEnumerationFails(_ fails: Bool) { enumerationFails = fails }
    func add(_ new: [ScreenshotAssetInfo]) { assets.append(contentsOf: new) }
    func replace(_ new: [ScreenshotAssetInfo]) { assets = new }

    func requestAccess() -> ScreenshotAccessStatus { access }

    func screenshotAssets() throws -> [ScreenshotAssetInfo] {
        if enumerationFails { throw ScreenshotProviderError.accessDenied(.restricted) }
        return assets
    }
}

/// Records every read, so "not re-scanned" is measured rather than assumed.
private actor FakeUnderstanding: ScreenshotUnderstanding {
    private var fallback: AssetScanOutcome = .paymentFound
    private var verdicts: [String: AssetScanOutcome] = [:]
    private(set) var reads: [String] = []

    func setFallback(_ outcome: AssetScanOutcome) { fallback = outcome }
    func set(_ outcome: AssetScanOutcome, for identifier: String) { verdicts[identifier] = outcome }

    func understand(_ asset: ScreenshotAssetInfo) -> AssetScanOutcome {
        reads.append(asset.identifier)
        return verdicts[asset.identifier] ?? fallback
    }
}
