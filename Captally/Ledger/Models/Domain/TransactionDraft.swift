import Foundation

/// What a deterministic parser extracted from one screenshot.
///
/// Amount, order number, transaction number and date only ever originate here. The semantic
/// layer is not allowed to produce them, so a hallucinating model cannot invent a payment.
struct ParsedTransaction: Equatable, Sendable {
    var amountMinor: Int64
    var currencyCode: String
    var type: TransactionType
    var date: Date
    var platform: CaptallyPlatform

    var merchantRaw: String?
    var orderNumber: String?
    var transactionNumber: String?
    var paymentMethod: String?
    var sourceAssetIdentifier: String?

    var ocrConfidence: Double = 0
    var parserConfidence: Double = 0
    var parserVersion: String?

    var amount: Decimal {
        MoneyAmount.decimal(fromMinorUnits: amountMinor, currencyCode: currencyCode)
    }
}

/// A transaction ready to be written to the ledger: parsed output plus classification,
/// confidence and review routing.
struct TransactionDraft: Equatable, Sendable {
    var amountMinor: Int64
    var currencyCode: String
    var type: TransactionType
    var date: Date
    var bookID: UUID
    var source: TransactionSource
    var reviewStatus: ReviewStatus

    var categoryID: UUID?
    var platform: CaptallyPlatform = .generic
    var merchantRaw: String?
    var merchantNormalized: String?
    var orderNumber: String?
    var transactionNumber: String?
    var paymentMethod: String?
    var sourceAssetIdentifier: String?
    var note: String?
    var estimatedDate: Date?
    var ocrConfidence: Double = 0
    var parserConfidence: Double = 0
    var semanticConfidence: Double = 0
    var finalConfidence: Double = 0
    var dedupFingerprint: String?
    var originalTransactionID: UUID?
    var parserVersion: String?
    var aiProvider: AIProviderIdentifier?
    var modelVersion: String?

    var amount: Decimal {
        MoneyAmount.decimal(fromMinorUnits: amountMinor, currencyCode: currencyCode)
    }

    init(
        amountMinor: Int64,
        currencyCode: String,
        type: TransactionType,
        date: Date,
        bookID: UUID,
        source: TransactionSource,
        reviewStatus: ReviewStatus,
        categoryID: UUID? = nil
    ) {
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.type = type
        self.date = date
        self.bookID = bookID
        self.source = source
        self.reviewStatus = reviewStatus
        self.categoryID = categoryID
    }

    init(parsed: ParsedTransaction, bookID: UUID, categoryID: UUID? = nil) {
        self.init(
            amountMinor: parsed.amountMinor,
            currencyCode: parsed.currencyCode,
            type: parsed.type,
            date: parsed.date,
            bookID: bookID,
            source: .screenshot,
            reviewStatus: .needsReview,
            categoryID: categoryID
        )
        platform = parsed.platform
        merchantRaw = parsed.merchantRaw
        orderNumber = parsed.orderNumber
        transactionNumber = parsed.transactionNumber
        paymentMethod = parsed.paymentMethod
        sourceAssetIdentifier = parsed.sourceAssetIdentifier
        ocrConfidence = parsed.ocrConfidence
        parserConfidence = parsed.parserConfidence
        parserVersion = parsed.parserVersion
    }
}
