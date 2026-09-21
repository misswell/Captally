import Foundation

/// A screenshot in the photo library, reduced to what scanning needs.
///
/// Only the local identifier is kept: Captally never copies screenshots into its own storage,
/// so the photo library stays the single place image bytes live.
struct ScreenshotAssetInfo: Equatable, Hashable, Sendable {
    let identifier: String
    let creationDate: Date
}

/// How far a screenshot got.
///
/// `pending` and `failed` stay eligible for a retry; the rest are terminal, so a screenshot is
/// never re-read once its verdict is known.
enum AssetScanOutcome: String, Codable, CaseIterable, Sendable {
    case pending
    case failed
    case notAPayment
    case paymentFound
    case skipped

    var isTerminal: Bool {
        switch self {
        case .pending, .failed: return false
        case .notAPayment, .paymentFound, .skipped: return true
        }
    }
}

enum CaptureBatchStatus: String, Codable, CaseIterable, Sendable {
    case running
    case completed
    case failed
    case cancelled
}

/// What one scan pass decided.
struct ScanReport: Equatable, Sendable {
    enum Skipped: String, Equatable, Sendable {
        case accessDenied
        case libraryUnavailable
    }

    var skipped: Skipped?
    var batchID: UUID?
    var discovered: [ScreenshotAssetInfo] = []
    var alreadyKnownCount = 0
    var libraryCount = 0

    var processedCount: Int { discovered.count }

    static let empty = ScanReport()
}
