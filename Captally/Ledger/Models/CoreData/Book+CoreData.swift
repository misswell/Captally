import Foundation
import CoreData

@objc(Book)
public class Book: NSManagedObject, Identifiable {
}

extension Book {
    @NSManaged public var createdAt: Date
    @NSManaged public var currency: String
    @NSManaged public var icon: String
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var categories: NSSet?
    @NSManaged public var transactions: NSSet?
    @NSManaged public var budgets: NSSet?
    @NSManaged public var accounts: NSSet?

    var transactionList: [Transaction] {
        (transactions?.allObjects as? [Transaction] ?? []).sorted { $0.date > $1.date }
    }

    var totalExpense: Decimal {
        transactionList
            .filter { $0.transactionType == .expense }
            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
    }

    /// Refunds are booked as their own transactions and reverse an expense, so they offset the
    /// spend total instead of appearing as income.
    var totalRefund: Decimal {
        transactionList
            .filter { $0.transactionType == .refund }
            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
    }

    var netExpense: Decimal {
        totalExpense - totalRefund
    }

    var totalIncome: Decimal {
        transactionList
            .filter { $0.transactionType == .income }
            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
    }

    var balance: Decimal {
        totalIncome - netExpense
    }

    static func create(
        in context: NSManagedObjectContext,
        name: String,
        icon: String = "book",
        currency: String = "CNY"
    ) -> Book {
        let book = Book(context: context)
        book.id = UUID()
        book.name = name
        book.icon = icon
        book.currency = currency
        book.createdAt = Date()
        return book
    }
}
