import CoreGraphics
import UIKit
import XCTest
@testable import Captally

/// The Understand layer's first brick, tested against the real recognizer: a payment screenshot is
/// mostly Chinese text plus digits, and if Vision cannot read those back with usable coordinates,
/// nothing downstream can be trusted.
@MainActor
final class OCRTests: XCTestCase {
    private func render(_ lines: [String], width: CGFloat = 620, height: CGFloat = 900) throws -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            var y: CGFloat = 60
            for line in lines {
                NSAttributedString(string: line, attributes: attributes)
                    .draw(at: CGPoint(x: 40, y: y))
                y += 90
            }
        }
        return try XCTUnwrap(image.cgImage)
    }

    // MARK: - Vision

    func testVisionReadsMerchantAndAmountLines() async throws {
        let recognizer = VisionTextRecognizer()
        let document = try await recognizer.recognize(
            in: render(["微信支付", "-28.50", "美团外卖", "订单号 1234567890"])
        )

        XCTAssertFalse(document.isEmpty)
        XCTAssertTrue(
            document.lineTexts.contains { $0.contains("微信支付") },
            "got \(document.lineTexts)"
        )
        XCTAssertTrue(
            document.lineTexts.contains { $0.contains("28.50") },
            "got \(document.lineTexts)"
        )
    }

    func testBoxesUseTheTopLeftOriginAndStayInsideTheImage() async throws {
        let document = try await VisionTextRecognizer().recognize(
            in: render(["TOP LINE", "MIDDLE LINE", "BOTTOM LINE"])
        )
        let boxes = document.lines.map(\.boundingBox)
        XCTAssertEqual(boxes.count, 3, "got \(document.lineTexts)")

        for box in boxes {
            XCTAssertGreaterThanOrEqual(box.minX, 0)
            XCTAssertGreaterThanOrEqual(box.minY, 0)
            XCTAssertLessThanOrEqual(box.maxX, 1)
            XCTAssertLessThanOrEqual(box.maxY, 1)
        }
        // The line drawn near the top of the image must sit near y = 0, not near y = 1.
        XCTAssertLessThan(boxes[0].minY, 0.25)
        XCTAssertGreaterThan(boxes[2].minY, boxes[0].minY)
        for (earlier, later) in zip(document.lines, document.lines.dropFirst()) {
            XCTAssertLessThanOrEqual(
                earlier.boundingBox.minY,
                later.boundingBox.minY + 0.01,
                "reading order broke: \(earlier.text) before \(later.text)"
            )
        }
    }

    func testConfidenceIsReportedForEveryLine() async throws {
        let document = try await VisionTextRecognizer().recognize(in: render(["支付宝", "12.00"]))
        XCTAssertFalse(document.isEmpty)
        for line in document.lines {
            XCTAssertTrue((0...1).contains(line.confidence), line.text)
        }
        XCTAssertGreaterThan(document.averageConfidence, 0.3)
    }

    func testBlankImageYieldsAnEmptyDocument() async throws {
        let bitmap = try render([])
        let document = try await VisionTextRecognizer().recognize(in: bitmap)
        XCTAssertTrue(document.isEmpty)
        XCTAssertEqual(document.averageConfidence, 0)
        // The document describes the bitmap it came from, in pixels rather than points.
        XCTAssertEqual(document.imageSize, CGSize(width: bitmap.width, height: bitmap.height))
    }

    // MARK: - Document

    func testDocumentDerivedViews() {
        let document = OCRDocument(
            imageSize: CGSize(width: 100, height: 200),
            lines: [
                OCRLine(boundingBox: CGRect(x: 0, y: 0, width: 1, height: 0.1), confidence: 0.9, text: "微信支付"),
                OCRLine(boundingBox: CGRect(x: 0, y: 0.2, width: 1, height: 0.1), confidence: 0.7, text: "-28.50"),
            ]
        )
        XCTAssertEqual(document.lineTexts, ["微信支付", "-28.50"])
        XCTAssertEqual(document.fullText, "微信支付\n-28.50")
        XCTAssertEqual(document.averageConfidence, 0.8, accuracy: 0.0001)
    }

    // MARK: - Screenshot entry point

    func testScreenshotOCRRequestsTheRecognizerSizeAndReturnsTheDocument() async throws {
        let loader = FakeImageLoader(bitmap: try render(["工商银行"]))
        let recognizer = ScriptedRecognizer(document: OCRDocument(
            imageSize: CGSize(width: 2048, height: 1200),
            lines: [OCRLine(boundingBox: .zero, confidence: 0.5, text: "工商银行")]
        ))
        let ocr = ScreenshotOCR(imageLoader: loader, recognizer: recognizer)

        let document = try await ocr.document(
            for: ScreenshotAssetInfo(identifier: "ASSET/1", creationDate: Date())
        )

        XCTAssertEqual(document.lineTexts, ["工商银行"])
        let request = await loader.lastRequest
        XCTAssertEqual(request?.identifier, "ASSET/1")
        XCTAssertEqual(request?.maxPixelSize, PhotoKitAssetImageLoader.defaultMaxPixelSize)
        XCTAssertEqual(request?.maxPixelSize, 2048, "the long edge must stay at the recognizer's working size")
    }

    func testScreenshotOCRPassesRecognitionFailuresThrough() async throws {
        let ocr = ScreenshotOCR(
            imageLoader: FakeImageLoader(bitmap: try render([])),
            recognizer: ScriptedRecognizer(error: TextRecognitionError.failed("boom"))
        )
        do {
            _ = try await ocr.document(
                for: ScreenshotAssetInfo(identifier: "ASSET/2", creationDate: Date())
            )
            XCTFail("a failed recognition must not look like an empty screenshot")
        } catch {
            XCTAssertEqual(error as? TextRecognitionError, .failed("boom"))
        }
    }
}

private actor FakeImageLoader: AssetImageLoading {
    struct Request: Equatable {
        let identifier: String
        let maxPixelSize: Int
    }

    private let bitmap: CGImage
    private(set) var lastRequest: Request?

    init(bitmap: CGImage) {
        self.bitmap = bitmap
    }

    func image(for identifier: String, maxPixelSize: Int) async throws -> CGImage {
        lastRequest = Request(identifier: identifier, maxPixelSize: maxPixelSize)
        return bitmap
    }
}

private struct ScriptedRecognizer: TextRecognizing {
    let document: OCRDocument?
    let error: TextRecognitionError?

    init(document: OCRDocument) {
        self.document = document
        self.error = nil
    }

    init(error: TextRecognitionError) {
        self.document = nil
        self.error = error
    }

    func recognize(in image: CGImage) async throws -> OCRDocument {
        if let error { throw error }
        return document ?? OCRDocument(imageSize: .zero, lines: [])
    }
}
