import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @StateObject private var statsVM = StatisticsViewModel()
    @Binding var selectedTab: Int

    @State private var selectedTopCategory: Category? = nil

    var body: some View {
        NavigationStack {
            Group {
                if let book = bookVM.currentBook {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Metrics.l) {
                            header(book: book)

                            Picker(loc["stats.period"], selection: $statsVM.selectedPeriod) {
                                ForEach(StatisticsViewModel.TimePeriod.allCases, id: \.self) { period in
                                    Text(loc["stats.\(period.rawValue.lowercased())"]).tag(period)
                                }
                            }
                            .pickerStyle(.segmented)

                            LedgerSummaryRow(expense: statsVM.totalExpense, income: statsVM.totalIncome)

                            trendCard
                            categoryCard
                        }
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.vertical, Metrics.m)
                    }
                    .softTopScrollEdge()
                } else {
                    ContentUnavailableView {
                        Label(loc["stats.noData"], systemImage: "chart.pie")
                    } description: {
                        Text(loc["stats.noDataDesc"])
                    } actions: {
                        Button(loc["quickEntry.createLedger"]) { selectedTab = AppTab.ledgers.rawValue }
                            .primaryAction(tint: .brand)
                    }
                }
            }
            .navigationTitle(loc["stats.title"])
            .navigationBarTitleDisplayMode(.inline)
            .collapsingTopBarOnScroll()
            .sheet(item: $selectedTopCategory) { category in
                if let book = bookVM.currentBook {
                    CategoryDetailView(category: category, book: book, statsVM: statsVM)
                }
            }
            .onAppear { refresh() }
            .onChange(of: bookVM.currentBook?.id) { _, _ in refresh() }
            .onChange(of: statsVM.selectedPeriod) { _, _ in statsVM.refreshCurrentData() }
        }
    }

    private func refresh() {
        if let book = bookVM.currentBook { statsVM.refreshData(for: book) }
    }

    private func header(book: Book) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.xs) {
                    Image(systemName: book.icon)
                        .foregroundStyle(Color.brand)
                    Text(book.name)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                }
                Text(statsVM.dateRangeLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Metrics.m)

            GlassGroup(spacing: Metrics.xs) {
                stepButton("chevron.left", action: statsVM.navigateBack)
                stepButton("chevron.right", action: statsVM.navigateForward)
            }
        }
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trend

    private var trendCard: some View {
        let data = statsVM.trendData

        return VStack(alignment: .leading, spacing: Metrics.m) {
            Text(loc["stats.trend"])
                .font(.headline)

            if data.isEmpty {
                Text(loc["stats.noChartData"])
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart(data) { point in
                    let expense = chartValue(point.expense)
                    let income = chartValue(point.income)

                    LineMark(
                        x: .value(loc["stats.date"], point.date),
                        y: .value(loc["bills.expense"], expense)
                    )
                    .foregroundStyle(Color.expenseColor)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value(loc["stats.date"], point.date),
                        y: .value(loc["bills.expense"], expense)
                    )
                    .foregroundStyle(Color.expenseColor.opacity(0.12))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value(loc["stats.date"], point.date),
                        y: .value(loc["bills.income"], income)
                    )
                    .foregroundStyle(Color.incomeColor)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value(loc["stats.date"], point.date),
                        y: .value(loc["bills.income"], income)
                    )
                    .foregroundStyle(Color.incomeColor.opacity(0.12))
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                }
                .frame(height: 180)
                .id(statsVM.selectedPeriod)

                HStack(spacing: Metrics.l) {
                    legend(color: .expenseColor, title: loc["bills.expense"])
                    legend(color: .incomeColor, title: loc["bills.income"])
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(Metrics.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private func legend(color: Color, title: String) -> some View {
        HStack(spacing: Metrics.xs) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 3)
            Text(title)
        }
    }

    // MARK: - Category breakdown

    private var categoryCard: some View {
        let categoryData = statsVM.expenseByCategory

        return VStack(alignment: .leading, spacing: Metrics.m) {
            Text(loc["stats.byCategory"])
                .font(.headline)

            if categoryData.isEmpty {
                Text(loc["stats.noChartData"])
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Chart(categoryData, id: \.0.id) { category, amount in
                    SectorMark(
                        angle: .value(loc["stats.amount"], chartValue(amount)),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(Color.categoryColor(for: categoryData.firstIndex(where: { $0.0.id == category.id }) ?? 0))
                    .cornerRadius(4)
                }
                .frame(height: 180)

                ForEach(Array(categoryData.prefix(5).enumerated()), id: \.offset) { index, item in
                    Button {
                        selectedTopCategory = item.0
                    } label: {
                        legendRow(item: item, index: index)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Metrics.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private func legendRow(item: (Category, Decimal), index: Int) -> some View {
        HStack(spacing: Metrics.s) {
            Circle()
                .fill(Color.categoryColor(for: index))
                .frame(width: 8, height: 8)

            Text(item.0.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: Metrics.s)

            Text(statsVM.totalExpense > 0 ? (item.1 / statsVM.totalExpense).percentageString : "0%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            Text(item.1.currencyString)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()

            if !statsVM.subCategories(of: item.0).isEmpty {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, Metrics.xs)
    }
}

/// Charts plot in Double; the ledger never leaves Decimal. This conversion stops at the axis.
private func chartValue(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
}

struct CategoryDetailView: View {
    let category: Category
    let book: Book
    @ObservedObject var statsVM: StatisticsViewModel
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.l) {
                    subCategorySection()
                    transactionListSection()
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, Metrics.m)
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc["stats.close"]) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func subCategorySection() -> some View {
        let subCategories = statsVM.expenseBySubCategory(parent: category)

        if !subCategories.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.m) {
                Text(loc["stats.subcategories"])
                    .font(.headline)

                Chart(subCategories, id: \.0.id) { subCategory, amount in
                    BarMark(
                        x: .value(loc["stats.amount"], chartValue(amount)),
                        y: .value(loc["stats.category"], subCategory.name)
                    )
                    .foregroundStyle(Color.categoryColor(for: subCategories.firstIndex(where: { $0.0.id == subCategory.id }) ?? 0))
                    .cornerRadius(4)
                }
                .frame(height: CGFloat(subCategories.count) * 36)

                ForEach(Array(subCategories.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: Metrics.s) {
                        Circle()
                            .fill(Color.categoryColor(for: index))
                            .frame(width: 8, height: 8)
                        Text(item.0.name)
                            .font(.subheadline)
                        Spacer(minLength: Metrics.s)
                        Text(item.1.currencyString)
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                    .padding(.vertical, Metrics.xs)
                }
            }
            .padding(Metrics.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface()
        }
    }

    private func transactionListSection() -> some View {
        let transactions = statsVM.transactions(by: category)

        return VStack(alignment: .leading, spacing: Metrics.m) {
            Text(loc["stats.transactions"])
                .font(.headline)

            if transactions.isEmpty {
                Text(loc["stats.noRecords"])
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(transactions, id: \.id) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .padding(Metrics.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }
}
