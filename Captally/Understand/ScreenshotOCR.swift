import CoreGraphics
import Foundation

/// A screenshot asset in, an `OCRDocument` out.
///
/// The image is decoded at the recognizer's working size and thrown away: Captally keeps
/// `PHAsset.localIdentifier` and the recognized text, never a copy of the screenshot.
struct ScreenshotOCR: Sendable {
    private let imageLoader: any AssetImageLoading
    private let recognizer: any TextRecognizing

    init(
        imageLoader: any AssetImageLoading = PhotoKitAssetImageLoader(),
        recognizer: any TextRecognizing = VisionTextRecognizer()
    ) {
        self.imageLoader = imageLoader
        self.recognizer = recognizer
    }

    func document(for asset: ScreenshotAssetInfo) async throws -> OCRDocument {
        let image = try await imageLoader.image(
            for: asset.identifier,
            maxPixelSize: PhotoKitAssetImageLoader.defaultMaxPixelSize
        )
        let document = try await recognizer.recognize(in: image)

        // Dimensions, line count and a score: recognized text is the user's financial data and
        // never reaches the log.
        CaptallyLog.ocr.info(
            "recognised \(document.lines.count, privacy: .public) lines at \(Int(document.imageSize.width), privacy: .public)x\(Int(document.imageSize.height), privacy: .public), confidence=\(Int(document.averageConfidence * 100), privacy: .public)%"
        )
        return document
    }
}
