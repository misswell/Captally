import Foundation
import Photos

enum ScreenshotAccessStatus: String, Sendable {
    case notDetermined
    case granted
    case limited
    case denied
    case restricted

    var canRead: Bool { self == .granted || self == .limited }
}

/// Reads the user's payment screenshots.
///
/// Implemented by PhotoKit in the app and by a fake in tests: the scan logic must be provable
/// without a photo library, because a duplicate scan is a duplicate expense.
protocol ScreenshotAssetProviding: Sendable {
    func requestAccess() async -> ScreenshotAccessStatus
    /// Ascending by creation date, oldest first.
    func screenshotAssets() async throws -> [ScreenshotAssetInfo]
}

enum ScreenshotProviderError: Error, Equatable {
    case accessDenied(ScreenshotAccessStatus)
}

struct PhotoKitScreenshotProvider: ScreenshotAssetProviding {
    /// `.readWrite` is the only access level PhotoKit grants for reading a library; Captally never
    /// writes, so `NSPhotoLibraryAddUsageDescription` stays out of Info.plist entirely.
    func requestAccess() async -> ScreenshotAccessStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: Self.map(status))
            }
        }
    }

    func screenshotAssets() async throws -> [ScreenshotAssetInfo] {
        let status = Self.currentAccessStatus()
        guard status.canRead else { throw ScreenshotProviderError.accessDenied(status) }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.fetchScreenshots())
            }
        }
    }

    // MARK: - Fetching

    /// Screenshots normally live in one smart album, so that is the only thing enumerated on the
    /// fast path. A library without that album falls back to PhotoKit's screenshot subtype flag —
    /// one bitwise test per image asset, unlike filename probing, which costs a resource fetch per
    /// asset.
    private static func fetchScreenshots() -> [ScreenshotAssetInfo] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        var fetched: [ScreenshotAssetInfo] = []
        func collect(_ asset: PHAsset) {
            guard let date = asset.creationDate else { return }
            fetched.append(
                ScreenshotAssetInfo(identifier: asset.localIdentifier, creationDate: date)
            )
        }

        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )
        collections.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            assets.enumerateObjects { asset, _, _ in collect(asset) }
        }
        guard fetched.isEmpty else { return fetched.sorted { $0.creationDate < $1.creationDate } }

        let images = PHAsset.fetchAssets(with: .image, options: options)
        images.enumerateObjects { asset, _, _ in
            if asset.mediaSubtypes.contains(.photoScreenshot) { collect(asset) }
        }
        return fetched.sorted { $0.creationDate < $1.creationDate }
    }

    // MARK: - Status mapping

    static func currentAccessStatus() -> ScreenshotAccessStatus {
        map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private static func map(_ status: PHAuthorizationStatus) -> ScreenshotAccessStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .granted
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .restricted
        }
    }
}
