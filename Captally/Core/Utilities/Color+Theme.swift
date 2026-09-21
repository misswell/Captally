import SwiftUI

extension Color {
    /// Sampled from the app icon, so the interface and the springboard agree.
    static let brand = Color(red: 92 / 255, green: 136 / 255, blue: 141 / 255)
    static let brandInk = Color(red: 48 / 255, green: 56 / 255, blue: 64 / 255)

    static let expenseColor = Color(red: 216 / 255, green: 95 / 255, blue: 79 / 255)
    static let incomeColor = Color(red: 40 / 255, green: 150 / 255, blue: 117 / 255)

    /// Category identity colours. Deliberately muted relative to the system palette: a ledger
    /// screen can show a dozen of these at once, and fully saturated hues compete for attention.
    static let categoryPalette: [Color] = [
        .brand,
        Color(red: 0.42, green: 0.51, blue: 0.69),
        Color(red: 0.76, green: 0.55, blue: 0.31),
        Color(red: 0.58, green: 0.40, blue: 0.60),
        Color(red: 0.33, green: 0.58, blue: 0.52),
        Color(red: 0.69, green: 0.41, blue: 0.37),
        Color(red: 0.47, green: 0.55, blue: 0.40),
        Color(red: 0.36, green: 0.48, blue: 0.58),
        Color(red: 0.65, green: 0.52, blue: 0.42),
        Color(red: 0.44, green: 0.44, blue: 0.58),
        Color(red: 0.30, green: 0.55, blue: 0.60),
        Color(red: 0.60, green: 0.47, blue: 0.55),
    ]

    static func categoryColor(for index: Int) -> Color {
        categoryPalette[abs(index) % categoryPalette.count]
    }
}
