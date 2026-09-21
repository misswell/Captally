import SwiftUI

struct BookManagementView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @StateObject private var budgetVM = BudgetViewModel()
    @State private var showAddBudget = false
    @State private var newBudgetAmount = ""
    @State private var newBudgetPeriod = BudgetPeriod.monthly

    var body: some View {
        NavigationStack {
            List {
                booksSection
                budgetSection
            }
            .navigationTitle(loc["ledgers.title"])
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        bookVM.showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $bookVM.showCreateSheet) {
                CreateBookView()
            }
            .alert(loc["ledgers.addBudget"], isPresented: $showAddBudget) {
                TextField(loc["ledgers.amount"], text: $newBudgetAmount)
                    .keyboardType(.decimalPad)
                Picker(loc["ledgers.period"], selection: $newBudgetPeriod) {
                    Text(loc["ledgers.monthly"]).tag(BudgetPeriod.monthly)
                    Text(loc["ledgers.yearly"]).tag(BudgetPeriod.yearly)
                }
                Button(loc["ledgers.cancel"], role: .cancel) { newBudgetAmount = "" }
                Button(loc["ledgers.add"]) {
                    if let book = bookVM.currentBook,
                       let amount = Decimal(string: newBudgetAmount), amount > 0 {
                        budgetVM.createBudget(for: book, amount: amount, period: newBudgetPeriod)
                    }
                    newBudgetAmount = ""
                }
            } message: {
                Text(loc["ledgers.enterBudgetAmount"])
            }
            .onChange(of: bookVM.currentBook) { _, newBook in
                if let book = newBook {
                    budgetVM.fetchBudgets(for: book)
                }
            }
        }
    }

    private var booksSection: some View {
        Section {
            ForEach(bookVM.books, id: \.id) { book in
                BookRow(book: book, isSelected: bookVM.currentBook?.id == book.id)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            bookVM.switchBook(to: book)
                        }
                    }
            }
            .onDelete { indexSet in
                let books = bookVM.books
                for index in indexSet {
                    bookVM.deleteBook(books[index])
                }
            }
        } header: {
            Label(loc["ledgers.personal"], systemImage: "person")
        }
    }

    private var budgetSection: some View {
        Section {
            if let book = bookVM.currentBook {
                ForEach(budgetVM.budgets, id: \.id) { budget in
                    BudgetProgressView(
                        budget: budget,
                        spent: budgetVM.spentAmount(for: budget, in: book),
                        total: budget.amount as Decimal
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        budgetVM.deleteBudget(budgetVM.budgets[index])
                    }
                }

                Button {
                    showAddBudget = true
                } label: {
                    Label(loc["ledgers.addBudget"], systemImage: "plus.circle")
                }
            }
        } header: {
            Label(loc["ledgers.budgets"], systemImage: "target")
        }
    }
}

struct BookRow: View {
    let book: Book
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Metrics.m) {
            Image(systemName: book.icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(width: 36, height: 36)
                .background(
                    isSelected ? Color.brand : Color(.secondarySystemFill),
                    in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                )

            Text(book.name)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: Metrics.s)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.brand)
            }
        }
        .padding(.vertical, Metrics.xs)
        .animation(.snappy, value: isSelected)
    }
}

struct CreateBookView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    private static let icons = [
        "book.fill", "house.fill", "airplane.departure", "cart.fill",
        "briefcase.fill", "heart.fill", "star.fill", "flag.fill",
        "wallet.pass.fill", "creditcard.fill", "pawprint.fill", "bag.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(loc["ledgers.basicInfo"]) {
                    TextField(loc["ledgers.ledgerName"], text: $bookVM.newBookName)
                }

                Section(loc["ledgers.icon"]) {
                    LazyVGrid(columns: Array(repeating: GridItem(), count: 6), spacing: Metrics.s) {
                        ForEach(Self.icons, id: \.self) { icon in
                            Button {
                                bookVM.newBookIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(bookVM.newBookIcon == icon ? Color.white : Color.primary)
                                    .background(
                                        bookVM.newBookIcon == icon ? Color.brand : Color(.secondarySystemFill),
                                        in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .sensoryFeedback(.selection, trigger: bookVM.newBookIcon)
                }
            }
            .navigationTitle(loc["ledgers.newLedger"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc["ledgers.cancel"]) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc["ledgers.create"]) {
                        bookVM.createBook()
                        dismiss()
                    }
                    .disabled(bookVM.newBookName.isEmpty)
                }
            }
        }
    }
}
