import SwiftUI

struct BudgetProgressView: View {
    @EnvironmentObject var loc: LocalizationManager
    let budget: Budget
    let spent: Decimal
    let total: Decimal

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(NSDecimalNumber(decimal: spent / total).doubleValue, 1.0)
    }

    private var isOverBudget: Bool {
        spent > total
    }

    private var isNearLimit: Bool {
        progress >= 0.8 && !isOverBudget
    }

    private var progressGradient: LinearGradient {
        if isOverBudget {
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        if progress < 0.5 {
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        if progress < 0.8 {
            return LinearGradient(
                colors: [Color.green, Color.yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Color.yellow, Color.red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.budgetPeriod == .monthly ? "Monthly Budget" : "Yearly Budget")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if isNearLimit {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if isOverBudget {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Text(spent.currencyString)
                    .font(.subheadline)
                    .foregroundStyle(isOverBudget ? .red : .primary)

                Text(" / ")

                Text(total.currencyString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)

            if isOverBudget {
                Text("Over budget \((spent - total).currencyString)")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(loc["budget.remaining"] + " \((total - spent).currencyString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
