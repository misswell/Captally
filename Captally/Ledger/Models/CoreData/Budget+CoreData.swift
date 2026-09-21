import Foundation
import CoreData

@objc(Budget)
public class Budget: NSManagedObject {
}

extension Budget {
    @NSManaged public var amount: NSDecimalNumber
    @NSManaged public var categoryId: UUID?
    @NSManaged public var id: UUID
    @NSManaged public var period: String
    @NSManaged public var startDate: Date
    @NSManaged public var book: Book?

    var budgetPeriod: BudgetPeriod {
        get { BudgetPeriod(rawValue: period) ?? .monthly }
        set { period = newValue.rawValue }
    }

    static func create(
        in context: NSManagedObjectContext,
        book: Book,
        amount: Decimal,
        period: BudgetPeriod = .monthly,
        categoryId: UUID? = nil,
        startDate: Date = Date()
    ) -> Budget {
        let budget = Budget(context: context)
        budget.id = UUID()
        budget.amount = NSDecimalNumber(decimal: amount)
        budget.budgetPeriod = period
        budget.categoryId = categoryId
        budget.startDate = startDate
        budget.book = book
        return budget
    }
}
