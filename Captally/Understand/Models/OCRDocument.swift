import CoreGraphics
import Foundation

/// One recognized run of text, positioned in the image it came from.
struct OCRLine: Equatable, Sendable {
    /// Unit rectangle, origin at the image's top-left with y growing downward — the convention
    /// every layout-aware reader assumes. Vision reports the same box from the bottom-left, and
    /// the flip happens once, in the recognizer, so nothing downstream has to know about it.
    let boundingBox: CGRect
    let confidence: Double
    let text: String
}

/// What a recognizer saw in one image.
///
/// Lines stay in the recognizer's reading order (top to bottom, left to right): payment
/// screenshots are read line by line, and the line after a merchant name is evidence about that
/// merchant.
struct OCRDocument: Equatable, Sendable {
    let imageSize: CGSize
    let lines: [OCRLine]

    var isEmpty: Bool { lines.isEmpty }

    var lineTexts: [String] { lines.map(\.text) }

    var fullText: String { lines.map(\.text).joined(separator: "\n") }

    /// The weakest link decides how much of this document can be trusted.
    var averageConfidence: Double {
        guard !lines.isEmpty else { return 0 }
        let total = lines.reduce(0) { $0 + $1.confidence }
        return total / Double(lines.count)
    }
}
