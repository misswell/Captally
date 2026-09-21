import SwiftUI

struct MonthPicker: View {
    @Binding var selectedDate: Date

    var body: some View {
        HStack(spacing: Metrics.xs) {
            step(-1, systemImage: "chevron.left")
            Text(selectedDate.formatted(.dateTime.year().month(.wide)))
                .font(.headline)
                .foregroundStyle(isCurrentMonth ? Color.brand : Color.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: selectedDate)
                .frame(maxWidth: .infinity)
            step(1, systemImage: "chevron.right")
        }
        .padding(.horizontal, Metrics.xs)
        .frame(height: Metrics.rowHeight)
        .glassKey(radius: Metrics.rowHeight / 2)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }

    private func step(_ months: Int, systemImage: String) -> some View {
        Button {
            selectedDate = selectedDate.adding(months: months)
        } label: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: Metrics.rowHeight, height: Metrics.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedDate.adding(months: months).formatted(.dateTime.year().month(.wide)))
    }
}
