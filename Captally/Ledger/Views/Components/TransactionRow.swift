import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: transaction.category?.icon ?? "questionmark")
                    .font(.callout)
                    .foregroundStyle(categoryColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(amountColor)

                Text(transaction.date.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    /// Screenshot-sourced rows lead with the merchant; the category is Captally's guess, the
    /// merchant is what the user actually paid.
    private var primaryTitle: String {
        if let merchant = transaction.merchantNormalized ?? transaction.merchantRaw, !merchant.isEmpty {
            return merchant
        }
        return transaction.category?.name ?? LocalizationManager.localized("component.uncategorized")
    }

    private var categoryColor: Color {
        guard let category = transaction.category else { return .gray }
        let topId: UUID = category.isTopLevel ? category.id : (category.parentId ?? category.id)
        let index = abs(topId.hashValue) % 12
        return Color.categoryColor(for: index)
    }

    private var amountText: String {
        let amount = (transaction.amount as Decimal).currencyString(currencyCode: transaction.resolvedCurrencyCode)
        switch transaction.transactionType {
        case .expense: return "-" + amount
        case .income, .refund: return "+" + amount
        case .transfer: return amount
        }
    }

    private var amountColor: Color {
        switch transaction.transactionType {
        case .expense: return .red
        case .income, .refund: return .green
        case .transfer: return .blue
        }
    }
}
