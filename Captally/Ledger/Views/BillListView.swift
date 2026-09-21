import SwiftUI
import CoreData

struct BillListView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedMonth = Date()
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var contentOpacity: Double = 1.0
    @State private var monthTransition: AnyTransition = .opacity
    @State private var appeared = false
    @State private var deletingTransactionId: NSManagedObjectID?
    @State private var deleteScale: CGFloat = 1.0

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>

    private var filteredTransactions: [Transaction] {
        let all = Array(transactions)
        if searchText.isEmpty || searchText == " " {
            return all
        }
        return all.filter { transaction in
            (transaction.note?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (transaction.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BookHeaderView()
                MonthPicker(selectedDate: $selectedMonth)

                if let book = bookVM.currentBook {
                    let filtered = filteredTransactions.filter { $0.book == book && isInSelectedMonth($0) }
                    summaryCard(transactions: filtered)
                        .opacity(contentOpacity)

                    if filtered.isEmpty {
                        emptyStateView
                            .opacity(contentOpacity)
                    } else {
                        transactionList(transactions: filtered)
                            .opacity(contentOpacity)
                    }
                } else {
                    ContentUnavailableView(
                        "No Ledger",
                        systemImage: "book",
                        description: Text("Create a ledger to start recording")
                    )
                }
            }
            .navigationTitle("Bills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSearch.toggle()
                            if !showSearch {
                                searchText = ""
                            } else {
                                searchText = " "
                            }
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .overlay(alignment: .top) {
                if showSearch {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search transactions", text: $searchText)
                                .textFieldStyle(.plain)
                            if !searchText.isEmpty && searchText != " " {
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        searchText = " "
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showSearch = false
                                searchText = ""
                            }
                        } label: {
                            Text("Cancel")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: selectedMonth) { _, _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    contentOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        contentOpacity = 1
                    }
                }
            }
            .onAppear {
                if !appeared {
                    appeared = true
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(.green.opacity(0.05))
                    .frame(width: 160, height: 160)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green.opacity(0.7))
                    .offset(y: -4)
            }

            VStack(spacing: 6) {
                Text(loc["bills.noExpenses"])
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(loc["bills.keepItUp"])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func isInSelectedMonth(_ transaction: Transaction) -> Bool {
        transaction.date >= selectedMonth.startOfMonth && transaction.date < selectedMonth.endOfMonth
    }

    private func summaryCard(transactions: [Transaction]) -> some View {
        let expense = transactions
            .filter { $0.transactionType == .expense }
            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
        let income = transactions
            .filter { $0.transactionType == .income }
            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }

        return HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Expense").font(.caption).foregroundStyle(.white.opacity(0.8))
                Text(expense.currencyString).font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.8), Color.red.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            VStack(spacing: 4) {
                Text("Income").font(.caption).foregroundStyle(.white.opacity(0.8))
                Text(income.currencyString).font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.8), Color.green.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            VStack(spacing: 4) {
                Text("Balance").font(.caption).foregroundStyle(.white.opacity(0.8))
                Text((income - expense).currencyString).font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func transactionList(transactions: [Transaction]) -> some View {
        let grouped = Dictionary(grouping: transactions) { Calendar.current.startOfDay(for: $0.date) }

        return List {
            ForEach(grouped.keys.sorted(by: >), id: \.self) { day in
                Section {
                    let dayTransactions = grouped[day] ?? []
                    ForEach(Array(dayTransactions.enumerated()), id: \.element.id) { index, transaction in
                        TransactionRow(transaction: transaction)
                            .offset(x: appeared ? 0 : 30)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.75)
                                    .delay(Double(index) * 0.05),
                                value: appeared
                            )
                            .scaleEffect(deletingTransactionId == transaction.objectID ? deleteScale : 1.0)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    performDelete(transaction)
                                } label: {
                                    Label(loc["bills.delete"], systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(day.formatted(.dateTime.month().day()))
                        Spacer()
                        let dayExpense = (grouped[day] ?? [])
                            .filter { $0.transactionType == .expense }
                            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
                        if dayExpense > 0 {
                            Text("-\(dayExpense.currencyString)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func performDelete(_ transaction: Transaction) {
        deletingTransactionId = transaction.objectID
        withAnimation(.easeIn(duration: 0.25)) {
            deleteScale = 0.01
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            viewContext.delete(transaction)
            try? viewContext.save()
            deletingTransactionId = nil
            deleteScale = 1.0
        }
    }
}
