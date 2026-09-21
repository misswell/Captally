import CoreData
import Foundation

/// Persistence boundary for transactions.
///
/// Parsers, the dedup engine and the capture pipeline go through this protocol instead of
/// touching `NSManagedObject`, which keeps Core Data out of the Understand and Tally layers.
protocol TransactionRepository: Sendable {
    @discardableResult
    func insert(_ draft: TransactionDraft) async throws -> UUID

    func transactionIDs(matchingAssetIdentifier identifier: String) async -> [UUID]

    func transactionIDs(matchingTransactionNumber number: String, platform: CaptallyPlatform) async -> [UUID]

    func transactionIDs(matchingFingerprint fingerprint: String) async -> [UUID]
}

enum TransactionRepositoryError: Error, Equatable {
    case bookNotFound(UUID)
    case categoryNotFound(UUID)
}

actor CoreDataTransactionRepository: TransactionRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    @discardableResult
    func insert(_ draft: TransactionDraft) async throws -> UUID {
        let id = UUID()
        return try await persistence.perform { context in
            _ = try Self.makeTransaction(id: id, draft: draft, in: context)
            return id
        }
    }

    func transactionIDs(matchingAssetIdentifier identifier: String) async -> [UUID] {
        await ids(predicate: NSPredicate(format: "sourceAssetIdentifier == %@", identifier))
    }

    func transactionIDs(matchingTransactionNumber number: String, platform: CaptallyPlatform) async -> [UUID] {
        await ids(
            predicate: NSPredicate(
                format: "transactionNumber == %@ AND sourcePlatform == %@",
                number,
                platform.rawValue
            )
        )
    }

    func transactionIDs(matchingFingerprint fingerprint: String) async -> [UUID] {
        await ids(predicate: NSPredicate(format: "dedupFingerprint == %@", fingerprint))
    }

    // MARK: - Helpers

    private func ids(predicate: NSPredicate) async -> [UUID] {
        (try? await persistence.perform { context in
            let request = NSFetchRequest<Transaction>(entityName: "Transaction")
            request.predicate = predicate
            return ((try? context.fetch(request)) ?? []).map(\.id)
        }) ?? []
    }

    private static func makeTransaction(
        id: UUID,
        draft: TransactionDraft,
        in context: NSManagedObjectContext
    ) throws -> Transaction {
        let bookRequest = NSFetchRequest<Book>(entityName: "Book")
        bookRequest.predicate = NSPredicate(format: "id == %@", draft.bookID as CVarArg)
        bookRequest.fetchLimit = 1
        guard let book = try? context.fetch(bookRequest).first else {
            throw TransactionRepositoryError.bookNotFound(draft.bookID)
        }

        var category: Category?
        if let categoryID = draft.categoryID {
            let categoryRequest = NSFetchRequest<Category>(entityName: "Category")
            categoryRequest.predicate = NSPredicate(format: "id == %@", categoryID as CVarArg)
            categoryRequest.fetchLimit = 1
            guard let match = try? context.fetch(categoryRequest).first else {
                throw TransactionRepositoryError.categoryNotFound(categoryID)
            }
            category = match
        }

        let transaction = Transaction(context: context)
        transaction.id = id
        transaction.book = book
        transaction.category = category
        transaction.amount = NSDecimalNumber(decimal: draft.amount)
        transaction.currencyCode = draft.currencyCode
        transaction.transactionType = draft.type
        transaction.date = draft.date
        transaction.estimatedDate = draft.estimatedDate
        transaction.note = draft.note
        transaction.transactionSource = draft.source
        transaction.platform = draft.platform
        transaction.currentReviewStatus = draft.reviewStatus

        transaction.merchantRaw = draft.merchantRaw
        transaction.merchantNormalized = draft.merchantNormalized
        transaction.orderNumber = draft.orderNumber
        transaction.transactionNumber = draft.transactionNumber
        transaction.paymentMethod = draft.paymentMethod
        transaction.sourceAssetIdentifier = draft.sourceAssetIdentifier
        transaction.ocrConfidence = draft.ocrConfidence
        transaction.parserConfidence = draft.parserConfidence
        transaction.semanticConfidence = draft.semanticConfidence
        transaction.finalConfidence = draft.finalConfidence
        transaction.dedupFingerprint = draft.dedupFingerprint
        transaction.originalTransactionID = draft.originalTransactionID
        transaction.parserVersion = draft.parserVersion
        transaction.providerIdentifier = draft.aiProvider
        transaction.modelVersion = draft.modelVersion
        transaction.createdAt = Date()
        transaction.updatedAt = Date()

        return transaction
    }
}
