import Foundation
import CoreData

@MainActor
class CategoryViewModel: ObservableObject {
    @Published var errorMessage: String? = nil
    private let loc = LocalizationManager()

    func addCategory(
        name: String,
        icon: String,
        type: CategoryType,
        to book: Book,
        parent: Category? = nil
    ) -> Bool {
        guard !name.isEmpty else {
            errorMessage = loc["validation.enterCategoryName"]
            return false
        }

        let context = PersistenceController.shared.viewContext

        let categories = book.categories?.allObjects as? [Category] ?? []
        let maxSortOrder = categories.map { $0.sortOrder }.max() ?? 0

        let _ = Category.create(
            in: context,
            name: name,
            icon: icon,
            categoryType: type,
            book: book,
            parentId: parent?.id,
            sortOrder: maxSortOrder + 1
        )

        do {
            try context.save()
            errorMessage = nil
            return true
        } catch {
            errorMessage = String(format: loc["validation.saveFailed"], error.localizedDescription)
            return false
        }
    }

    func updateCategory(
        _ category: Category,
        name: String,
        icon: String
    ) -> Bool {
        guard !name.isEmpty else {
            errorMessage = loc["validation.enterCategoryName"]
            return false
        }

        category.name = name
        category.icon = icon

        guard let error = PersistenceController.shared.save() else {
            errorMessage = nil
            return true
        }
        errorMessage = String(format: loc["validation.saveFailed"], error.localizedDescription)
        return false
    }

    func deleteCategory(_ category: Category) -> Bool {
        guard category.canDelete else {
            errorMessage = loc["validation.cannotDeleteDefault"]
            return false
        }

        if let transactionCount = category.transactions?.count, transactionCount > 0 {
            errorMessage = String(format: loc["validation.categoryHasRecords"], transactionCount)
            return false
        }

        PersistenceController.shared.delete(category)
        errorMessage = nil
        return true
    }

    func moveCategory(_ categories: [Category], from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, cat) in reordered.enumerated() {
            cat.sortOrder = Int32(index)
        }

        if let error = PersistenceController.shared.save() {
            errorMessage = String(format: loc["validation.saveFailed"], error.localizedDescription)
        }
    }

    func moveUp(_ category: Category, in categories: [Category]) {
        guard let currentIndex = categories.firstIndex(where: { $0.id == category.id }),
              currentIndex > 0 else { return }

        let previous = categories[currentIndex - 1]
        let tempSort = category.sortOrder
        category.sortOrder = previous.sortOrder
        previous.sortOrder = tempSort

        if let error = PersistenceController.shared.save() {
            errorMessage = String(format: loc["validation.saveFailed"], error.localizedDescription)
        }
    }

    func moveDown(_ category: Category, in categories: [Category]) {
        guard let currentIndex = categories.firstIndex(where: { $0.id == category.id }),
              currentIndex < categories.count - 1 else { return }

        let next = categories[currentIndex + 1]
        let tempSort = category.sortOrder
        category.sortOrder = next.sortOrder
        next.sortOrder = tempSort

        if let error = PersistenceController.shared.save() {
            errorMessage = String(format: loc["validation.saveFailed"], error.localizedDescription)
        }
    }

    func getCategories(for book: Book, type: CategoryType) -> [Category] {
        let categories = book.categories?.allObjects as? [Category] ?? []
        return categories
            .filter { $0.categoryType == type && $0.isTopLevel }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func getSubCategories(for parent: Category) -> [Category] {
        guard let book = parent.book else { return [] }
        let categories = book.categories?.allObjects as? [Category] ?? []
        return categories
            .filter { $0.parentId == parent.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
