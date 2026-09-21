import Foundation

enum TransactionType: String, Codable, CaseIterable, Sendable {
    case expense
    case income
    case refund
    case transfer

    /// Types offered by manual entry. `refund` and `transfer` are produced by the screenshot
    /// pipeline, where the originating order is known; entering them by hand invites the user to
    /// book a refund as if it were income and lose the link to the original expense.
    static let manualEntryCases: [TransactionType] = [.expense, .income]

    /// Refund reverses an expense rather than adding to it, so it is neither income nor expense.
    var affectsExpense: Bool {
        self == .expense || self == .refund
    }

    var affectsIncome: Bool {
        self == .income
    }
}
