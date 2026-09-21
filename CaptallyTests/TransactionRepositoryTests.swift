import CoreData
import XCTest
@testable import Captally

/// Covers the persistence boundary the parsers, dedup engine and capture pipeline will use:
/// a value-type draft in, fetchable identifiers out, without Core Data leaking upward.
@MainActor
final class TransactionRepositoryTests: XCTestCase {
    private var environment: AppEnvironment!
    private var bookID = UUID()

    override func setUpWithError() throws {
        environment = AppEnvironment.ephemeral()
        let context = environment.persistence.viewContext
        let book = Book.create(in: context, name: "Repository test")
        try context.save()
        bookID = book.id
    }

    override func tearDown() {
        environment = nil
        super.tearDown()
    }

    func testInsertWritesEveryProvenanceField() async throws {
        var draft = TransactionDraft(
            amountMinor: 2850,
            currencyCode: "CNY",
            type: .expense,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            bookID: bookID,
            source: .screenshot,
            reviewStatus: .needsReview
        )
        draft.platform = .alipay
        draft.merchantRaw = "全家便利店"
        draft.merchantNormalized = "familymart"
        draft.transactionNumber = "2023111522001234567890"
        draft.sourceAssetIdentifier = "PHAsset:ABC123"
        draft.dedupFingerprint = "fp-abc"
        draft.ocrConfidence = 0.91
        draft.parserConfidence = 0.88
        draft.parserVersion = "1.0.0"

        let id = try await environment.transactionRepository.insert(draft)

        let transaction = try XCTUnwrap(try fetchTransaction(id: id))
        XCTAssertEqual(transaction.amount as Decimal, try XCTUnwrap(Decimal(string: "28.50")))
        XCTAssertEqual(transaction.amountMinor, 2850)
        XCTAssertEqual(transaction.transactionSource, .screenshot)
        XCTAssertEqual(transaction.currentReviewStatus, .needsReview)
        XCTAssertEqual(transaction.platform, .alipay)
        XCTAssertEqual(transaction.merchantRaw, "全家便利店")
        XCTAssertEqual(transaction.transactionNumber, "2023111522001234567890")
        XCTAssertEqual(transaction.sourceAssetIdentifier, "PHAsset:ABC123")
        XCTAssertEqual(transaction.dedupFingerprint, "fp-abc")
        XCTAssertEqual(transaction.ocrConfidence, 0.91, accuracy: 0.0001)
        XCTAssertEqual(transaction.parserVersion, "1.0.0")
        XCTAssertNil(transaction.providerIdentifier)
    }

    func testUnknownBookIsRejected() async throws {
        let draft = TransactionDraft(
            amountMinor: 100,
            currencyCode: "CNY",
            type: .expense,
            date: Date(),
            bookID: UUID(),
            source: .manual,
            reviewStatus: .userConfirmed
        )
        var thrown: Error?
        do {
            _ = try await environment.transactionRepository.insert(draft)
        } catch {
            thrown = error
        }
        XCTAssertEqual(thrown as? TransactionRepositoryError, .bookNotFound(draft.bookID))
    }

    func testDuplicateLookupsFindByAssetNumberAndFingerprint() async throws {
        let repository = environment.transactionRepository
        let first = try await repository.insert(draft(
            transactionNumber: "TX-1",
            assetIdentifier: "PHAsset:ONE",
            fingerprint: "FP-1"
        ))
        _ = try await repository.insert(draft(
            transactionNumber: "TX-2",
            assetIdentifier: "PHAsset:TWO",
            fingerprint: "FP-2"
        ))

        let byAsset = await repository.transactionIDs(matchingAssetIdentifier: "PHAsset:ONE")
        XCTAssertEqual(byAsset, [first])

        let byNumber = await repository.transactionIDs(
            matchingTransactionNumber: "TX-1",
            platform: .alipay
        )
        XCTAssertEqual(byNumber, [first])

        let byFingerprint = await repository.transactionIDs(matchingFingerprint: "FP-1")
        XCTAssertEqual(byFingerprint, [first])

        let misses = await repository.transactionIDs(matchingAssetIdentifier: "PHAsset:MISSING")
        XCTAssertTrue(misses.isEmpty)

        // The same order number on another platform must not collide.
        let otherPlatform = await repository.transactionIDs(
            matchingTransactionNumber: "TX-1",
            platform: .wechatPay
        )
        XCTAssertTrue(otherPlatform.isEmpty)
    }

    /// Reads through the view context so the managed object stays on the context that owns it.
    private func fetchTransaction(id: UUID) throws -> Transaction? {
        let request = NSFetchRequest<Transaction>(entityName: "Transaction")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try environment.persistence.viewContext.fetch(request).first
    }

    private func draft(transactionNumber: String, assetIdentifier: String, fingerprint: String) -> TransactionDraft {
        var draft = TransactionDraft(
            amountMinor: 1234,
            currencyCode: "CNY",
            type: .expense,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            bookID: bookID,
            source: .screenshot,
            reviewStatus: .needsReview
        )
        draft.platform = .alipay
        draft.transactionNumber = transactionNumber
        draft.sourceAssetIdentifier = assetIdentifier
        draft.dedupFingerprint = fingerprint
        return draft
    }
}
