import Foundation
import CoreData

@MainActor
class BudgetViewModel: ObservableObject {
    private let persistenceController: PersistenceController

    @Published var budgets: [Budget] = []

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    func fetchBudgets(for book: Book) {
        budgets = (book.budgets?.allObjects as? [Budget]) ?? []
    }

    func spentAmount(for budget: Budget, in book: Book) -> Decimal {
        guard let book = budget.book else { return 0 }
        let transactions = (book.transactions?.allObjects as? [Transaction]) ?? []
        let now = Date()

        let filtered: [Transaction]
        switch budget.budgetPeriod {
        case .monthly:
            filtered = transactions.filter {
                $0.transactionType == .expense &&
                $0.date >= now.startOfMonth && $0.date < now.endOfMonth
            }
        case .yearly:
            filtered = transactions.filter {
                $0.transactionType == .expense &&
                $0.date >= now.startOfYear && $0.date < now.endOfYear
            }
        }

        if let categoryId = budget.categoryId {
            return filtered
                .filter { $0.category?.id == categoryId || $0.category?.parentId == categoryId }
                .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
        }

        return filtered.reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
    }

    func progress(for budget: Budget, in book: Book) -> Double {
        let budgetAmount = budget.amount as Decimal
        guard budgetAmount > 0 else { return 0 }
        let spent = spentAmount(for: budget, in: book)
        return min(NSDecimalNumber(decimal: spent / budgetAmount).doubleValue, 1.0)
    }

    func isOverBudget(_ budget: Budget, in book: Book) -> Bool {
        spentAmount(for: budget, in: book) > (budget.amount as Decimal)
    }

    func createBudget(for book: Book, amount: Decimal, period: BudgetPeriod = .monthly, categoryId: UUID? = nil) {
        let context = persistenceController.viewContext
        let _ = Budget.create(
            in: context,
            book: book,
            amount: amount,
            period: period,
            categoryId: categoryId
        )
        persistenceController.save()
        fetchBudgets(for: book)
    }

    func deleteBudget(_ budget: Budget) {
        persistenceController.delete(budget)
        budgets.removeAll { $0 == budget }
    }
}
