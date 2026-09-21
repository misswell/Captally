import Foundation
import CoreData

@MainActor
class BookViewModel: ObservableObject {
    let persistenceController: PersistenceController

    @Published var books: [Book] = []
    @Published var currentBook: Book?
    @Published var showCreateSheet = false
    @Published var newBookName = ""
    @Published var newBookIcon = "book"

    private var cancellables: [Any] = []

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        fetchBooks()
        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: persistenceController.viewContext,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fetchBooks()
            }
        }
    }

    func fetchBooks() {
        let request = NSFetchRequest<Book>(entityName: "Book")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        books = (try? persistenceController.viewContext.fetch(request)) ?? []

        if currentBook == nil, let first = books.first {
            currentBook = first
        } else if let current = currentBook, !books.contains(where: { $0.id == current.id }) {
            currentBook = books.first
        }
    }

    @discardableResult
    func createBook() -> Book {
        let context = persistenceController.viewContext
        let book = Book.create(
            in: context,
            name: newBookName,
            icon: newBookIcon
        )

        Category.createDefaultCategories(for: book, in: context)

        persistenceController.save()
        fetchBooks()
        currentBook = book
        resetForm()
        return book
    }

    func deleteBook(_ book: Book) {
        if currentBook == book {
            currentBook = books.first { $0 != book }
        }
        persistenceController.delete(book)
        fetchBooks()
    }

    func switchBook(to book: Book) {
        currentBook = book
    }

    private func resetForm() {
        newBookName = ""
        newBookIcon = "book"
        showCreateSheet = false
    }
}
