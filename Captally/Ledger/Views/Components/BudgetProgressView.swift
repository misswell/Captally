import SwiftUI

struct BudgetProgressView: View {
    @EnvironmentObject var loc: LocalizationManager
    let budget: Budget
    let spent: Decimal
    let total: Decimal

    private var isOverBudget: Bool { spent > total }

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: spent / total).doubleValue, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.xs) {
            HStack {
                Label(
                    budget.budgetPeriod == .monthly ? loc["budget.monthly"] : loc["budget.yearly"],
                    systemImage: isOverBudget ? "exclamationmark.triangle.fill" : "target"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOverBudget ? Color.expenseColor : Color.primary)

                Spacer(minLength: Metrics.s)

                Text("\(spent.currencyString) / \(total.currencyString)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: ratio)
                .tint(tintColor)

            if isOverBudget {
                Text("\(loc["budget.overBudget"]) \((spent - total).currencyString)")
                    .font(.caption)
                    .foregroundStyle(Color.expenseColor)
            } else {
                Text("\(loc["budget.remaining"]) \((total - spent).currencyString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Metrics.xs)
    }

    private var tintColor: Color {
        if isOverBudget { return .expenseColor }
        if ratio >= 0.8 { return .orange }
        return .brand
    }
}
