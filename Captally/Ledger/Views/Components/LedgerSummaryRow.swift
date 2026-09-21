import SwiftUI

/// Expense / income / balance for one period. Shared by the Bills and Stats tabs so the two
/// screens agree on what the numbers look like.
struct LedgerSummaryRow: View {
    @EnvironmentObject var loc: LocalizationManager
    let expense: Decimal
    let income: Decimal

    var body: some View {
        HStack(spacing: 0) {
            metric(loc["bills.expense"], expense, .expenseColor)
            metric(loc["bills.income"], income, .incomeColor)
            metric(loc["bills.balance"], income - expense, .brand)
        }
        .padding(.vertical, Metrics.m)
        .glassSurface(Metrics.cardRadius)
    }

    private func metric(_ title: String, _ amount: Decimal, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount.currencyString)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
