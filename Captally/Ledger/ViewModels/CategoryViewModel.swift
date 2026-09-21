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

    func deleteCategory(_ category: Category) {
        guard category.canDelete else {
            errorMessage = loc["validation.cannotDeleteDefault"]
            return
        }

        if let transactionCount = category.transactions?.count, transactionCount > 0 {
            errorMessage = String(format: loc["validation.categoryHasRecords"], transactionCount)
            return
        }

        PersistenceController.shared.delete(category)
        errorMessage = nil
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

    func getCategories(for book: Book, type: CategoryType, topLevel: Bool = true) -> [Category] {
        let categories = book.categories?.allObjects as? [Category] ?? []
        return categories
            .filter { $0.categoryType == type && $0.isTopLevel == topLevel }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}
