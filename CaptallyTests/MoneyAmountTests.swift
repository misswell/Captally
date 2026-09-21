import XCTest
@testable import Captally

/// The dedup engine fingerprints minor units, so this conversion is load-bearing: two textual
/// spellings of the same payment must produce the same integer key. Hashing `Decimal.description`
/// would not, because scale and trailing zeros survive in it.
final class MoneyAmountTests: XCTestCase {
    func testTrailingZerosCollapseToTheSameMinorUnits() throws {
        for spelling in ["28.5", "28.50", "28.500", "028.50"] {
            XCTAssertEqual(
                MoneyAmount.minorUnits(decimal: try XCTUnwrap(Decimal(string: spelling)), currencyCode: "CNY"),
                2850,
                spelling
            )
        }
    }

    func testFractionDigitsFollowISO4217() {
        XCTAssertEqual(MoneyAmount.fractionDigits(for: "CNY"), 2)
        XCTAssertEqual(MoneyAmount.fractionDigits(for: "usd"), 2)
        XCTAssertEqual(MoneyAmount.fractionDigits(for: "JPY"), 0)
        XCTAssertEqual(MoneyAmount.fractionDigits(for: "KRW"), 0)
        XCTAssertEqual(MoneyAmount.fractionDigits(for: "KWD"), 3)
        XCTAssertEqual(MoneyAmount.fractionDigits(for: "BHD"), 3)
    }

    func testZeroAndThreeDigitCurrenciesScaleCorrectly() throws {
        XCTAssertEqual(MoneyAmount.minorUnits(decimal: 1234, currencyCode: "JPY"), 1234)
        XCTAssertEqual(MoneyAmount.minorUnits(decimal: 1234, currencyCode: "jpy"), 1234)
        XCTAssertEqual(
            MoneyAmount.minorUnits(
                decimal: try XCTUnwrap(Decimal(string: "12.345")),
                currencyCode: "KWD"
            ),
            12_345
        )
    }

    func testRoundsHalfAwayFromZeroAtTheMinorBoundary() throws {
        XCTAssertEqual(
            MoneyAmount.minorUnits(decimal: try XCTUnwrap(Decimal(string: "28.565")), currencyCode: "CNY"),
            2857
        )
        XCTAssertEqual(
            MoneyAmount.minorUnits(decimal: try XCTUnwrap(Decimal(string: "-28.565")), currencyCode: "CNY"),
            -2857
        )
    }

    func testMinorUnitRoundTripKeepsExactValue() throws {
        for minor: Int64 in [0, 1, 99, 100, 2857, -2857, 12_345_678] {
            let decimal = MoneyAmount.decimal(fromMinorUnits: minor, currencyCode: "CNY")
            XCTAssertEqual(
                MoneyAmount.minorUnits(decimal: decimal, currencyCode: "CNY"),
                minor,
                "round trip lost precision for \(minor)"
            )
        }
        XCTAssertEqual(MoneyAmount.decimal(fromMinorUnits: 2857, currencyCode: "CNY"), Decimal(string: "28.57"))
        XCTAssertEqual(MoneyAmount.decimal(fromMinorUnits: 500, currencyCode: "JPY"), 500)
    }
}
