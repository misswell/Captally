import Foundation
import CoreData
import SwiftUI

@MainActor
class StatisticsViewModel: ObservableObject {
    @Published var selectedPeriod: TimePeriod = .month
    @Published var selectedDate: Date = Date()
    @Published var cachedTransactions: [Transaction] = []

    private var currentBook: Book?

    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }

    struct TrendDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let expense: Decimal
        let income: Decimal
        var balance: Decimal { income - expense }
    }

    func refreshData(for book: Book) {
        currentBook = book
        loadTransactions()
    }

    func refreshCurrentData() {
        guard currentBook != nil else { return }
        loadTransactions()
    }

    private func loadTransactions() {
        guard let book = currentBook else { return }
        let all = book.transactions?.allObjects as? [Transaction] ?? []
        cachedTransactions = all.filter { dateRange.contains($0.date) }
    }

    var dateRange: DateInterval {
        switch selectedPeriod {
        case .week:
            let start = selectedDate.adding(days: -6).startOfDay
            return DateInterval(start: start, end: selectedDate.endOfDay)
        case .month:
            return DateInterval(start: selectedDate.startOfMonth, end: selectedDate.endOfMonth)
        case .year:
            return DateInterval(start: selectedDate.startOfYear, end: selectedDate.endOfYear)
        }
    }

    func navigateBack() {
        switch selectedPeriod {
        case .week: selectedDate = selectedDate.adding(days: -7)
        case .month: selectedDate = selectedDate.adding(months: -1)
        case .year:
            if let d = Calendar.current.date(byAdding: .year, value: -1, to: selectedDate) {
                selectedDate = d
            }
        }
        loadTransactions()
    }

    func navigateForward() {
        switch selectedPeriod {
        case .week: selectedDate = selectedDate.adding(days: 7)
        case .month: selectedDate = selectedDate.adding(months: 1)
        case .year:
            if let d = Calendar.current.date(byAdding: .year, value: 1, to: selectedDate) {
                selectedDate = d
            }
        }
        loadTransactions()
    }

    var totalExpense: Decimal {
        cachedTransactions
            .filter { $0.transactionType == .expense }
            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
    }

    var totalIncome: Decimal {
        cachedTransactions
            .filter { $0.transactionType == .income }
            .reduce(Decimal(0)) { $0 + ($1.amount as Decimal) }
    }

    var totalBalance: Decimal {
        totalIncome - totalExpense
    }

    var expenseByCategory: [(Category, Decimal)] {
        let expenses = cachedTransactions.filter { $0.transactionType == .expense }
        var totals: [UUID: Decimal] = [:]
        var map: [UUID: Category] = [:]

        for t in expenses {
            guard let cat = t.category else { continue }
            let top: Category
            if cat.isTopLevel {
                top = cat
            } else if let pid = cat.parentId,
                      let book = currentBook,
                      let parent = (book.categories?.allObjects as? [Category])?.first(where: { $0.id == pid }) {
                top = parent
            } else {
                top = cat
            }
            totals[top.id, default: 0] += t.amount as Decimal
            map[top.id] = top
        }

        return totals.compactMap { (id, total) in
            guard let c = map[id] else { return nil }
            return (c, total)
        }.sorted { $0.1 > $1.1 }
    }

    func subCategories(of parent: Category) -> [Category] {
        guard let book = currentBook else { return [] }
        let all = book.categories?.allObjects as? [Category] ?? []
        return all.filter { $0.parentId == parent.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func expenseBySubCategory(parent: Category) -> [(Category, Decimal)] {
        let expenses = cachedTransactions.filter { $0.transactionType == .expense }
        var totals: [UUID: Decimal] = [:]
        var map: [UUID: Category] = [:]

        for t in expenses {
            guard let cat = t.category else { continue }
            if cat.parentId == parent.id {
                totals[cat.id, default: 0] += t.amount as Decimal
                map[cat.id] = cat
            }
        }

        return totals.compactMap { (id, total) in
            guard let c = map[id] else { return nil }
            return (c, total)
        }.sorted { $0.1 > $1.1 }
    }

    func transactions(by category: Category) -> [Transaction] {
        cachedTransactions
            .filter { $0.category?.id == category.id || $0.category?.parentId == category.id }
            .sorted { $0.date > $1.date }
    }

    var trendData: [TrendDataPoint] {
        switch selectedPeriod {
        case .week, .month: dailyTrendData
        case .year: monthlyTrendData
        }
    }

    private var dailyTrendData: [TrendDataPoint] {
        let cal = Calendar.current
        var expByDate: [Date: Decimal] = [:]
        var incByDate: [Date: Decimal] = [:]

        for t in cachedTransactions {
            let day = cal.startOfDay(for: t.date)
            if t.transactionType == .expense {
                expByDate[day, default: 0] += t.amount as Decimal
            } else {
                incByDate[day, default: 0] += t.amount as Decimal
            }
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"

        var points: [TrendDataPoint] = []
        var cur = dateRange.start
        while cur < dateRange.end {
            let e = expByDate[cur] ?? 0
            let i = incByDate[cur] ?? 0
            points.append(TrendDataPoint(date: cur, label: fmt.string(from: cur), expense: e, income: i))
            guard let next = cal.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = next
        }
        return points
    }

    private var monthlyTrendData: [TrendDataPoint] {
        let cal = Calendar.current
        var expByMonth: [Date: Decimal] = [:]
        var incByMonth: [Date: Decimal] = [:]

        for t in cachedTransactions {
            let comps = cal.dateComponents([.year, .month], from: t.date)
            guard let monthStart = cal.date(from: comps) else { continue }
            if t.transactionType == .expense {
                expByMonth[monthStart, default: 0] += t.amount as Decimal
            } else {
                incByMonth[monthStart, default: 0] += t.amount as Decimal
            }
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"

        var points: [TrendDataPoint] = []
        var cur = dateRange.start
        while cur < dateRange.end {
            let comps = cal.dateComponents([.year, .month], from: cur)
            guard let monthStart = cal.date(from: comps) else { break }
            let e = expByMonth[monthStart] ?? 0
            let i = incByMonth[monthStart] ?? 0
            points.append(TrendDataPoint(date: monthStart, label: fmt.string(from: monthStart), expense: e, income: i))
            guard let next = cal.date(byAdding: .month, value: 1, to: cur) else { break }
            cur = next
        }
        return points
    }

    var dateRangeLabel: String {
        let fmt = DateFormatter()
        switch selectedPeriod {
        case .week:
            fmt.dateFormat = "MMM d"
            return "\(fmt.string(from: dateRange.start)) - \(fmt.string(from: dateRange.end.adding(days: -1)))"
        case .month:
            fmt.dateFormat = "MMM yyyy"
            return fmt.string(from: selectedDate)
        case .year:
            fmt.dateFormat = "yyyy"
            return fmt.string(from: selectedDate)
        }
    }
}
