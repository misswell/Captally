import SwiftUI
import CoreData

struct BillListView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.managedObjectContext) private var viewContext

    @Binding var selectedTab: Int

    @State private var selectedMonth = Date()
    @State private var searchText = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>

    var body: some View {
        NavigationStack {
            Group {
                if bookVM.currentBook != nil {
                    content
                } else {
                    ContentUnavailableView {
                        Label(loc["bills.noLedger"], systemImage: "book.closed")
                    } description: {
                        Text(loc["bills.noLedgerDesc"])
                    } actions: {
                        Button(loc["quickEntry.createLedger"]) { selectedTab = AppTab.ledgers.rawValue }
                            .primaryAction(tint: .brand)
                    }
                }
            }
            .navigationTitle(loc["bills.title"])
            .navigationBarTitleDisplayMode(.inline)
            .collapsingTopBarOnScroll()
            .searchable(text: $searchText, prompt: Text(loc["bills.search"]))
        }
    }

    private var content: some View {
        let monthTransactions = visibleTransactions.filter(isInSelectedMonth)

        return VStack(spacing: Metrics.s) {
            MonthPicker(selectedDate: $selectedMonth)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.s)

            LedgerSummaryRow(expense: totalExpense(monthTransactions), income: totalIncome(monthTransactions))
                .padding(.horizontal, Metrics.gutter)

            if monthTransactions.isEmpty {
                ContentUnavailableView(
                    loc["bills.noExpenses"],
                    systemImage: "leaf",
                    description: Text(loc["bills.keepItUp"])
                )
                .frame(maxHeight: .infinity)
            } else {
                transactionList(monthTransactions)
            }
        }
    }

    private func totalExpense(_ transactions: [Transaction]) -> Decimal {
        transactions.filter { $0.transactionType == .expense }.reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
    }

    private func totalIncome(_ transactions: [Transaction]) -> Decimal {
        transactions.filter { $0.transactionType == .income }.reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
    }

    private var visibleTransactions: [Transaction] {
        let all = transactions.filter { $0.book == bookVM.currentBook }
        guard !searchText.isEmpty else { return all }
        return all.filter { transaction in
            (transaction.note?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            transaction.category?.name.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    private func isInSelectedMonth(_ transaction: Transaction) -> Bool {
        transaction.date >= selectedMonth.startOfMonth && transaction.date < selectedMonth.endOfMonth
    }

    private func transactionList(_ transactions: [Transaction]) -> some View {
        let grouped = Dictionary(grouping: transactions) { Calendar.current.startOfDay(for: $0.date) }

        return List {
            ForEach(grouped.keys.sorted(by: >), id: \.self) { day in
                Section {
                    ForEach(grouped[day] ?? [], id: \.objectID) { transaction in
                        TransactionRow(transaction: transaction)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    delete(transaction)
                                } label: {
                                    Label(loc["bills.delete"], systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(day.formatted(.dateTime.weekday(.abbreviated).month().day()))
                        Spacer()
                        let dayExpense = (grouped[day] ?? []).filter { $0.transactionType == .expense }
                            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
                        if dayExpense > 0 {
                            Text("-\(dayExpense.currencyString)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .softTopScrollEdge()
    }

    private func delete(_ transaction: Transaction) {
        viewContext.delete(transaction)
        try? viewContext.save()
    }
}
