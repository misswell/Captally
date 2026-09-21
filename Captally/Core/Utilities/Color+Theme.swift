import SwiftUI

extension Color {
    static let appPrimary = Color("AppPrimary")
    static let appSecondary = Color("AppSecondary")
    static let appBackground = Color("AppBackground")
    static let appCard = Color("AppCard")
    static let appText = Color("AppText")
    static let appTextSecondary = Color("AppTextSecondary")
    static let appExpense = Color("AppExpense")
    static let appIncome = Color("AppIncome")

    static let expenseColor = Color(red: 0.91, green: 0.30, blue: 0.24)
    static let incomeColor = Color(red: 0.20, green: 0.78, blue: 0.55)

    static let expenseGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.91, green: 0.30, blue: 0.24), location: 0),
            .init(color: Color(red: 0.95, green: 0.45, blue: 0.30), location: 0.6),
            .init(color: Color(red: 0.97, green: 0.58, blue: 0.35), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let incomeGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.15, green: 0.70, blue: 0.48), location: 0),
            .init(color: Color(red: 0.20, green: 0.78, blue: 0.55), location: 0.6),
            .init(color: Color(red: 0.30, green: 0.85, blue: 0.62), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let balanceGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.25, green: 0.55, blue: 0.95), location: 0),
            .init(color: Color(red: 0.35, green: 0.65, blue: 0.98), location: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let toastBackground = Color(UIColor.darkGray).opacity(0.88)

    static let cardShadow = Color.black.opacity(0.08)

    static func categoryColor(for index: Int) -> Color {
        let colors: [Color] = [
            .orange, .blue, .purple, .pink, .teal,
            .indigo, .mint, .cyan, .brown, .yellow,
            .red, .green
        ]
        return colors[index % colors.count]
    }
}
