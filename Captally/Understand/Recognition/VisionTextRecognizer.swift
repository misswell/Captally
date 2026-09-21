import CoreGraphics
import Foundation
import Vision

/// Reads the text out of an image.
///
/// Implemented by Vision in the app and by a scripted fake in tests: the rules that decide
/// whether a screenshot is a payment have to be testable without running a recognizer.
protocol TextRecognizing: Sendable {
    func recognize(in image: CGImage) async throws -> OCRDocument
}

enum TextRecognitionError: Error, Equatable {
    /// Vision refused the request outright. Carries no image content.
    case failed(String)
}

/// Apple's on-device text recognizer.
///
/// On-device only, by design: `VNRecognizeTextRequest` never leaves the phone, which is what lets
/// Captally promise that a payment screenshot is read locally.
struct VisionTextRecognizer: TextRecognizing {
    /// Chinese payment screenshots mix scripts in one line — 微信支付、支付宝、美团、¥28.50、订单号.
    static let recognitionLanguages = ["zh-Hans", "en-US"]

    func recognize(in image: CGImage) async throws -> OCRDocument {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OCRDocument, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try Self.perform(on: image) })
            }
        }
    }

    private static func perform(on image: CGImage) throws -> OCRDocument {
        let request = VNRecognizeTextRequest()
        // .accurate: a screenshot is a still, high-contrast image and a wrong digit is a wrong
        // expense, so there is nothing to gain from the faster level.
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = recognitionLanguages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw TextRecognitionError.failed(String(describing: type(of: error)))
        }

        let observations = request.results ?? []
        // Vision already reports observations in reading order; re-sorting them by geometry would
        // only break lines that sit at the same height in two columns.
        let lines: [OCRLine] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRLine(
                boundingBox: Self.flippedBox(of: observation),
                confidence: Double(candidate.confidence),
                text: candidate.string
            )
        }

        return OCRDocument(
            imageSize: CGSize(width: image.width, height: image.height),
            lines: lines
        )
    }

    /// Vision's unit box has its origin at the image's bottom-left.
    static func flippedBox(of observation: VNRecognizedTextObservation) -> CGRect {
        let box = observation.boundingBox
        return CGRect(
            x: box.minX,
            y: 1 - box.maxY,
            width: box.width,
            height: box.height
        )
    }
}
