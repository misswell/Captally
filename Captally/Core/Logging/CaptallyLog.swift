import os

/// Capture -> Understand -> Tally pipeline logging.
///
/// Release logs carry identifiers and scores only. Never log OCR text, amounts, merchant
/// names, order or transaction numbers, card details, or asset identifiers: those are the
/// user's financial data.
enum CaptallyLog {
    static let subsystem = "com.misswell.Captally"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let cloudKit = Logger(subsystem: subsystem, category: "cloudkit")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let parser = Logger(subsystem: subsystem, category: "parser")
    static let dedup = Logger(subsystem: subsystem, category: "dedup")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let tally = Logger(subsystem: subsystem, category: "tally")
}
