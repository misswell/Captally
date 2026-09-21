import SwiftUI

struct MonthPicker: View {
    @Binding var selectedDate: Date
    var onNavigate: (() -> Void)? = nil
    @State private var monthText: String = ""
    @State private var slideDirection: Bool = true
    @State private var leftPressed = false
    @State private var rightPressed = false

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }

    private func updateMonthText() {
        monthText = selectedDate.formatted(.dateTime.year().month(.wide))
    }

    var body: some View {
        HStack {
            Button {
                slideDirection = false
                selectedDate = selectedDate.adding(months: -1)
                withAnimation(.easeInOut(duration: 0.25)) {
                    updateMonthText()
                }
                onNavigate?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .scaleEffect(leftPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: leftPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                leftPressed = pressing
            }, perform: {})

            Spacer()

            Text(monthText)
                .font(.headline)
                .foregroundStyle(isCurrentMonth ? Color.accentColor : .primary)
                .contentTransition(.numericText())
                .id(monthText)
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: slideDirection ? .leading : .trailing).combined(with: .opacity)
                ))

            Spacer()

            Button {
                slideDirection = true
                selectedDate = selectedDate.adding(months: 1)
                withAnimation(.easeInOut(duration: 0.25)) {
                    updateMonthText()
                }
                onNavigate?()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .scaleEffect(rightPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: rightPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                rightPressed = pressing
            }, perform: {})
        }
        .padding(.horizontal)
        .onAppear {
            updateMonthText()
        }
    }
}
