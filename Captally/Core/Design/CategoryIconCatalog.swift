import SwiftUI

/// SF Symbols offered when naming a category.
///
/// Kept in one place because the picker appears both in the ledger and in the quick-add sheet: the
/// list is stored on the `Category` itself, so the set of symbols here is also the set the app
/// promises to keep rendering.
enum CategoryIcons {
    static let fallback = "fork.knife"

    static let all: [String] = [
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "wineglass.fill", "birthday.cake.fill", "mug.fill", "apple.fill", "bag.fill",
        "car.fill", "bus.fill", "tram.fill", "car.side.fill", "fuelpump.fill",
        "parkingsign.circle.fill", "bicycle", "airplane.departure", "shirt.fill",
        "house.fill", "building.fill", "bolt.fill", "building.2.fill", "laptopcomputer.and.iphone",
        "drop.fill", "handbag.fill", "tv.fill", "wrench.and.screwdriver.fill", "flame.fill",
        "wifi", "gamecontroller.fill", "film.fill", "figure.run", "music.note",
        "person.2.fill", "dice.fill", "ticket.fill", "stethoscope", "pills.fill",
        "heart.text.square.fill", "mouth.fill", "heart.circle.fill", "book.fill",
        "graduationcap.fill", "doc.text.fill", "pencil", "phone.fill", "shippingbox.fill",
        "person.crop.circle.fill", "gift.fill", "banknote.fill", "heart.fill", "pawprint.fill",
        "chart.line.uptrend.xyaxis", "chart.bar.fill", "percent", "coins", "briefcase.fill",
        "star.fill", "star.circle.fill", "arrow.uturn.backward.circle.fill", "lightbulb.fill",
        "leaf.fill", "tag.fill", "cart.fill", "creditcard.fill", "wallet.pass.fill",
        "calendar", "clock.fill", "plus.circle.fill", "building.columns.fill",
        "character.book.fill", "person.wave.2.fill", "pencil.line",
    ]
}

/// The icon grid used by every category editor: one tile per symbol, selected tile in brand ink.
struct CategoryIconGrid: View {
    @Binding var selection: String
    let columns: Int

    init(selection: Binding<String>, columns: Int = 7) {
        self._selection = selection
        self.columns = columns
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(), count: columns), spacing: Metrics.s) {
            ForEach(CategoryIcons.all, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Image(systemName: option)
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(option == selection ? Color.white : Color.primary)
                        .background(
                            option == selection ? Color.brand : Color(.secondarySystemFill),
                            in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
