import SwiftUI
import Charts

struct CategoryPieChart: View {
    let data: [(category: String, amount: Decimal, color: Color)]

    var body: some View {
        Chart(data, id: \.category) { item in
            SectorMark(
                angle: .value("Amount", Double(truncating: NSDecimalNumber(decimal: item.amount))),
                innerRadius: .ratio(0.5),
                angularInset: 1.5
            )
            .foregroundStyle(item.color)
        }
        .frame(height: 200)
        .overlay {
            if let top = data.first {
                VStack(spacing: 2) {
                    Text(top.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(top.amount.currencyString)
                        .font(.headline)
                }
            }
        }
    }
}
