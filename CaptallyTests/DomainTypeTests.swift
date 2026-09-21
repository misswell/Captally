import XCTest
@testable import Captally

/// Core Data stores these as strings; the business layer must stay strongly typed and must not
/// crash on a raw value written by a future app version.
final class DomainTypeTests: XCTestCase {
    func testRawValuesRoundTrip() {
        for value in TransactionSource.allCases {
            XCTAssertEqual(TransactionSource(rawValue: value.rawValue), value)
        }
        for value in ReviewStatus.allCases {
            XCTAssertEqual(ReviewStatus(rawValue: value.rawValue), value)
        }
        for value in TransactionType.allCases {
            XCTAssertEqual(TransactionType(rawValue: value.rawValue), value)
        }
        for value in AIProviderIdentifier.allCases {
            XCTAssertEqual(AIProviderIdentifier(rawValue: value.rawValue), value)
        }
        for value in CaptallyPlatform.allCases {
            XCTAssertEqual(CaptallyPlatform(rawValue: value.rawValue), value)
        }
    }

    func testUnknownRawValuesFallBackInsteadOfCrashing() {
        XCTAssertEqual(CaptallyPlatform.from(rawValue: "weChat-beta-v9"), .generic)
        XCTAssertEqual(CaptallyPlatform.from(rawValue: nil), .generic)
        XCTAssertEqual(CaptallyPlatform.from(rawValue: "alipay"), .alipay)
    }

    func testManualEntryHidesTypesOnlyScreenshotsProduce() {
        XCTAssertEqual(TransactionType.manualEntryCases, [.expense, .income])
        XCTAssertTrue(TransactionType.refund.affectsExpense)
        XCTAssertFalse(TransactionType.refund.affectsIncome)
        XCTAssertFalse(TransactionType.transfer.affectsExpense)
        XCTAssertFalse(TransactionType.transfer.affectsIncome)
    }

    func testDraftFromParserIsRoutedForReviewAndTaggedAsScreenshot() throws {
        let parsed = ParsedTransaction(
            amountMinor: 2850,
            currencyCode: "CNY",
            type: .expense,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            platform: .alipay,
            merchantRaw: "全家便利店",
            sourceAssetIdentifier: "PH-123"
        )
        let draft = TransactionDraft(parsed: parsed, bookID: UUID())

        XCTAssertEqual(draft.source, .screenshot)
        XCTAssertEqual(draft.reviewStatus, .needsReview)
        XCTAssertEqual(draft.platform, .alipay)
        XCTAssertEqual(draft.amount, Decimal(string: "28.50"))
        XCTAssertEqual(draft.ocrConfidence, 0)
        XCTAssertNil(draft.aiProvider)
    }
}
