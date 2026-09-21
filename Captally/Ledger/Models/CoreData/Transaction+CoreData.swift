import Foundation
import CoreData

@objc(Transaction)
public class Transaction: NSManagedObject, Identifiable {
}

extension Transaction {
    @NSManaged public var amount: NSDecimalNumber
    @NSManaged public var createdAt: Date
    @NSManaged public var date: Date
    @NSManaged public var id: UUID
    @NSManaged public var note: String?
    @NSManaged public var tagsData: Data?
    @NSManaged public var type: String
    @NSManaged public var updatedAt: Date

    // Captally auto-tally provenance. All optional so a V1 store upgrades without backfill.
    @NSManaged public var aiProvider: String?
    @NSManaged public var currencyCode: String?
    @NSManaged public var dedupFingerprint: String?
    @NSManaged public var estimatedDate: Date?
    @NSManaged public var finalConfidence: Double
    @NSManaged public var merchantNormalized: String?
    @NSManaged public var merchantRaw: String?
    @NSManaged public var modelVersion: String?
    @NSManaged public var ocrConfidence: Double
    @NSManaged public var orderNumber: String?
    @NSManaged public var originalTransactionID: UUID?
    @NSManaged public var parserConfidence: Double
    @NSManaged public var parserVersion: String?
    @NSManaged public var paymentMethod: String?
    @NSManaged public var reviewStatus: String?
    @NSManaged public var semanticConfidence: Double
    @NSManaged public var source: String?
    @NSManaged public var sourceAssetIdentifier: String?
    @NSManaged public var sourcePlatform: String?
    @NSManaged public var transactionNumber: String?

    @NSManaged public var book: Book?
    @NSManaged public var category: Category?

    var transactionType: TransactionType {
        get { TransactionType(rawValue: type) ?? .expense }
        set { type = newValue.rawValue }
    }

    var transactionSource: TransactionSource {
        get { TransactionSource(rawValue: source ?? "") ?? .manual }
        set { source = newValue.rawValue }
    }

    var platform: CaptallyPlatform {
        get { CaptallyPlatform.from(rawValue: sourcePlatform) }
        set { sourcePlatform = newValue.rawValue }
    }

    var currentReviewStatus: ReviewStatus {
        get { ReviewStatus(rawValue: reviewStatus ?? "") ?? .userConfirmed }
        set { reviewStatus = newValue.rawValue }
    }

    var providerIdentifier: AIProviderIdentifier? {
        get { aiProvider.flatMap(AIProviderIdentifier.init(rawValue:)) }
        set { aiProvider = newValue?.rawValue }
    }

    /// Amounts are stored as exact `Decimal`; minor units exist for fingerprinting only.
    var amountMinor: Int64 {
        MoneyAmount.minorUnits(decimal: amount as Decimal, currencyCode: resolvedCurrencyCode)
    }

    var resolvedCurrencyCode: String {
        currencyCode ?? book?.currency ?? "CNY"
    }

    var isScreenshotSourced: Bool {
        transactionSource == .screenshot
    }

    var tagsList: [String] {
        get {
            guard let data = tagsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            tagsData = try? JSONEncoder().encode(newValue)
        }
    }

    var formattedAmount: String {
        (amount as Decimal).currencyString(currencyCode: resolvedCurrencyCode)
    }

    static func create(
        in context: NSManagedObjectContext,
        amount: Decimal,
        type: TransactionType,
        category: Category,
        book: Book,
        note: String? = nil,
        tags: [String] = [],
        date: Date = Date()
    ) -> Transaction {
        let transaction = Transaction(context: context)
        transaction.id = UUID()
        transaction.amount = NSDecimalNumber(decimal: amount)
        transaction.transactionType = type
        transaction.note = note
        transaction.tagsList = tags
        transaction.date = date
        transaction.createdAt = Date()
        transaction.updatedAt = Date()
        transaction.category = category
        transaction.book = book
        transaction.currencyCode = book.currency
        transaction.transactionSource = .manual
        transaction.currentReviewStatus = .userConfirmed
        return transaction
    }
}
