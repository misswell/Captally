import Foundation

/// Turns "what the Understand layer concluded about one screenshot" into a durable decision.
protocol ScreenshotUnderstanding: Sendable {
    func understand(_ asset: ScreenshotAssetInfo) async -> AssetScanOutcome
}

/// Used until Vision OCR lands (Stage 3). `skipped` is terminal on purpose: these screenshots are
/// seen again only if their recorded verdict is cleared, so the pre-OCR pass cannot leave a
/// backlog it re-walks on every launch.
struct UnconfiguredScreenshotUnderstanding: ScreenshotUnderstanding {
    func understand(_ asset: ScreenshotAssetInfo) async -> AssetScanOutcome { .skipped }
}

/// Finds screenshots Captally has not finished reading yet and reads them oldest first.
///
/// The whole set is one subtraction: the photo library minus what the capture store already
/// settled. Nothing else is needed to make a pass incremental — an asset that was re-dated,
/// re-ordered or restored from iCloud still cannot be read twice, and a pass that died halfway
/// leaves its unfinished assets eligible. A date cursor on top of this buys no speed (the library
/// has to be enumerated either way) and can strand an old screenshot that appears later, so
/// Captally keeps no second source of truth about scan progress.
actor ScreenshotScanCoordinator {
    /// How many times one screenshot may fail before the scanner stops trying it.
    static let maxRetries = 3

    private let provider: any ScreenshotAssetProviding
    private let state: any CaptureStateStoring
    private let understanding: any ScreenshotUnderstanding
    private let maxRetries: Int
    private var activeScan: Task<ScanReport, Never>?
    private var scanGeneration: UInt64 = 0

    init(
        provider: any ScreenshotAssetProviding,
        state: any CaptureStateStoring,
        understanding: any ScreenshotUnderstanding = UnconfiguredScreenshotUnderstanding(),
        maxRetries: Int = ScreenshotScanCoordinator.maxRetries
    ) {
        self.provider = provider
        self.state = state
        self.understanding = understanding
        self.maxRetries = maxRetries
    }

    func currentAccessStatus() async -> ScreenshotAccessStatus {
        await provider.requestAccess()
    }

    /// A foreground resume, a library change and a manual refresh can land together; concurrent
    /// passes would double-register the same screenshots, so a second caller joins the first.
    func scan() async -> ScanReport {
        if let activeScan { return await activeScan.value }
        scanGeneration += 1
        let generation = scanGeneration
        let task = Task { await self.performScan() }
        activeScan = task
        let report = await task.value
        if generation == scanGeneration { activeScan = nil }
        return report
    }

    private func performScan() async -> ScanReport {
        let access = await provider.requestAccess()
        guard access.canRead else {
            CaptallyLog.capture.info("scan skipped, library access is \(access.rawValue, privacy: .public)")
            return ScanReport(skipped: .accessDenied)
        }

        let library: [ScreenshotAssetInfo]
        do {
            library = try await provider.screenshotAssets()
        } catch {
            CaptallyLog.capture.notice("screenshot enumeration unavailable")
            return ScanReport(skipped: .libraryUnavailable)
        }

        let settled = await state.settledIdentifiers(maxRetries: maxRetries)
        let discovered = library
            .filter { !settled.contains($0.identifier) }
            .sorted { $0.creationDate < $1.creationDate }
        let alreadyKnown = library.count - discovered.count

        // Counts only: an asset identifier is a pointer into someone's photo library.
        CaptallyLog.capture.info(
            "scan saw \(library.count, privacy: .public) screenshots, \(settled.count, privacy: .public) settled, \(discovered.count, privacy: .public) to read"
        )

        guard !discovered.isEmpty else {
            return ScanReport(
                alreadyKnownCount: alreadyKnown,
                libraryCount: library.count
            )
        }

        let batchID = await state.beginBatch()
        await state.register(discovered, batchID: batchID)
        await read(discovered, batchID: batchID)

        let status: CaptureBatchStatus = Task.isCancelled ? .cancelled : .completed
        await state.endBatch(batchID, status: status, scannedCount: discovered.count)

        return ScanReport(
            batchID: batchID,
            discovered: discovered,
            alreadyKnownCount: library.count - discovered.count,
            libraryCount: library.count
        )
    }

    // MARK: - Steps

    private func read(_ assets: [ScreenshotAssetInfo], batchID: UUID) async {
        for asset in assets {
            if Task.isCancelled { return }
            let outcome = await understanding.understand(asset)
            await state.setOutcome(outcome, for: asset.identifier)
        }
    }
}
