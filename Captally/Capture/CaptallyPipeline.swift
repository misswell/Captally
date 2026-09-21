import Foundation
import Photos

/// Composition root for the capture loop.
///
/// Holds the pieces the rest of Capture depends on so nothing reaches for a singleton, and is the
/// only Capture type the app layer talks to.
@MainActor
final class CaptallyPipeline: ObservableObject {
    let coordinator: ScreenshotScanCoordinator

    @Published private(set) var lastReport = ScanReport.empty
    @Published private(set) var accessStatus: ScreenshotAccessStatus = .notDetermined
    @Published private(set) var isScanning = false

    private let libraryChanges = ScreenshotLibraryObserver()

    init(
        provider: any ScreenshotAssetProviding = PhotoKitScreenshotProvider(),
        state: any CaptureStateStoring
    ) {
        coordinator = ScreenshotScanCoordinator(
            provider: provider,
            state: state
        )
    }

    /// Registers for photo-library changes and runs the first pass. The pass is what asks for
    /// read-only access, so this is called from the UI rather than from `init`.
    func start() async {
        libraryChanges.startObserving { [weak self] in
            Task { await self?.scanNow() }
        }
        await scanNow()
    }

    func stop() {
        libraryChanges.stopObserving()
    }

    @discardableResult
    func scanNow() async -> ScanReport {
        isScanning = true
        let report = await coordinator.scan()
        accessStatus = await coordinator.currentAccessStatus()
        isScanning = false
        lastReport = report
        return report
    }
}

/// Bridges PhotoKit's change callbacks onto the main queue.
///
/// Separate from the pipeline because the observer must be a class registered with the shared
/// library, and its callback arrives on a PhotoKit queue.
final class ScreenshotLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    private var onChange: (() -> Void)?
    private var isRegistered = false

    func startObserving(onChange: @escaping () -> Void) {
        self.onChange = onChange
        guard !isRegistered else { return }
        isRegistered = true
        PHPhotoLibrary.shared().register(self)
    }

    func stopObserving() {
        guard isRegistered else { return }
        isRegistered = false
        onChange = nil
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }
}
