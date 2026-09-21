import CoreGraphics
import Foundation
import Photos

/// Decodes a screenshot into a bitmap for OCR.
///
/// Images are decoded at the size the recognizer needs, never larger: a 1320×2868 screenshot
/// costs several MB as `CGImage`, and OCR accuracy does not improve above ~2048px on the long
/// edge. Nothing is written back out to disk.
protocol AssetImageLoading: Sendable {
    func image(for identifier: String, maxPixelSize: Int) async throws -> CGImage
}

enum AssetImageLoaderError: Error, Equatable {
    case assetMissing(String)
    case decodeFailed
}

struct PhotoKitAssetImageLoader: AssetImageLoading {
    static let defaultMaxPixelSize = 2048

    func image(for identifier: String, maxPixelSize: Int = PhotoKitAssetImageLoader.defaultMaxPixelSize) async throws -> CGImage {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetch.firstObject else {
            throw AssetImageLoaderError.assetMissing(identifier)
        }
        let side = max(1, maxPixelSize)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast

        return try await withCheckedThrowingContinuation { continuation in
            func fail() { continuation.resume(throwing: AssetImageLoaderError.decodeFailed) }
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: side, height: side),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if (info?[PHImageCancelledKey] as? Bool) == true {
                    fail()
                } else if let bitmap = image?.cgImage {
                    continuation.resume(returning: bitmap)
                } else {
                    fail()
                }
            }
        }
    }
}
