import SwiftUI
import Charts

struct TrendChartView: View {
    let data: [(date: Date, amount: Decimal)]

    var body: some View {
        Chart(data, id: \.date) { item in
            LineMark(
                x: .value("Date", item.date),
                y: .value("Amount", Double(truncating: NSDecimalNumber(decimal: item.amount)))
            )
            .foregroundStyle(.red)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", item.date),
                y: .value("Amount", Double(truncating: NSDecimalNumber(decimal: item.amount)))
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [.red.opacity(0.3), .red.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxisLabel("¥")
    }
}
