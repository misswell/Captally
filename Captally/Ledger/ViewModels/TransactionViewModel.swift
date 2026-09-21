import Foundation
import CoreData

@MainActor
class TransactionViewModel: ObservableObject {
    @Published var amountText: String = ""
    @Published var selectedType: TransactionType = .expense
    @Published var selectedCategory: Category?
    @Published var note: String = ""
    @Published var tags: [String] = []
    @Published var date: Date = Date()
    @Published var currentBook: Book?

    var amount: Decimal {
        Decimal(string: amountText) ?? 0
    }

    var canSave: Bool {
        amount > 0 && selectedCategory != nil && currentBook != nil
    }

    func saveTransaction() -> Bool {
        guard canSave, let book = currentBook, let category = selectedCategory else { return false }

        let context = PersistenceController.shared.viewContext

        let _ = Transaction.create(
            in: context,
            amount: amount,
            type: selectedType,
            category: category,
            book: book,
            note: note.isEmpty ? nil : note,
            tags: tags,
            date: date
        )

        do {
            try context.save()
            resetForm()
            return true
        } catch {
            print("Save error: \(error)")
            return false
        }
    }

    func deleteTransaction(_ transaction: Transaction) {
        let context = PersistenceController.shared.viewContext
        context.delete(transaction)
        try? context.save()
    }

    func resetForm() {
        amountText = ""
        note = ""
        tags = []
        date = Date()
    }

    func expenseCategories(for book: Book) -> [Category] {
        let categories = book.categories?.allObjects as? [Category] ?? []
        return categories
            .filter { $0.categoryType == .expense && $0.isTopLevel }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func incomeCategories(for book: Book) -> [Category] {
        let categories = book.categories?.allObjects as? [Category] ?? []
        return categories
            .filter { $0.categoryType == .income && $0.isTopLevel }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func subCategories(of parent: Category) -> [Category] {
        guard let book = parent.book else { return [] }
        let categories = book.categories?.allObjects as? [Category] ?? []
        return categories
            .filter { $0.parentId == parent.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
