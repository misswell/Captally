import Foundation

/// Minor-unit money conversions.
///
/// The Core Data store keeps exact `Decimal` amounts; the dedup and fingerprint layers work in
/// integer minor units so that `28.50`, `28.5` and `¥28.50` all collapse to the same hash key.
/// Hashing `Decimal.description` would not: it preserves trailing-zero and scale differences.
enum MoneyAmount {
    private static let roundingToInteger = rounding(scale: 0)

    private static func rounding(scale: Int16) -> NSDecimalNumberHandler {
        NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: scale,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    }

    static func minorUnits(decimal: Decimal, currencyCode: String) -> Int64 {
        let scaled = (decimal as NSDecimalNumber).multiplying(
            by: NSDecimalNumber(decimal: pow10(fractionDigits(for: currencyCode)))
        )
        return scaled.rounding(accordingToBehavior: roundingToInteger).int64Value
    }

    static func decimal(fromMinorUnits minor: Int64, currencyCode: String) -> Decimal {
        let exponent = fractionDigits(for: currencyCode)
        let quotient = NSDecimalNumber(value: minor).dividing(
            by: NSDecimalNumber(decimal: pow10(exponent)),
            withBehavior: rounding(scale: Int16(exponent))
        )
        return quotient.decimalValue
    }

    /// ISO 4217 minor units. Two digits is the common case; only the exceptions are listed.
    static func fractionDigits(for currencyCode: String) -> Int {
        let code = currencyCode.uppercased()
        if zeroDigitCodes.contains(code) { return 0 }
        if threeDigitCodes.contains(code) { return 3 }
        return 2
    }

    private static let zeroDigitCodes: Set<String> = [
        "BIF", "CLP", "DJF", "JPY", "KMF", "KRW", "PYG", "RWF",
        "UGX", "VND", "VUV", "XAF", "XOF", "XPF"
    ]

    private static let threeDigitCodes: Set<String> = [
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"
    ]

    private static func pow10(_ exponent: Int) -> Decimal {
        switch exponent {
        case 0: return Decimal(1)
        case 1: return Decimal(10)
        case 2: return Decimal(100)
        default: return Decimal(1000)
        }
    }
}
