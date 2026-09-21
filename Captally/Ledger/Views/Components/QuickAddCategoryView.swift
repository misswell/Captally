import SwiftUI
import CoreData

struct QuickAddCategoryView: View {
    @EnvironmentObject var loc: LocalizationManager
    let book: Book
    let categoryType: CategoryType
    let parentCategory: Category?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var categoryVM = CategoryViewModel()

    @State private var name: String = ""
    @State private var icon: String = "fork.knife"
    @FocusState private var isNameFocused: Bool

    let iconOptions = [
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "wineglass.fill", "birthday.cake.fill", "mug.fill", "apple.fill", "bag.fill",
        "car.fill", "bus.fill", "tram.fill", "car.side.fill", "fuelpump.fill",
        "parkingsign.circle.fill", "bicycle", "airplane.departure",
        "bag.fill", "shirt.fill", "house.fill", "laptopcomputer.and.iphone",
        "drop.fill", "handbag.fill", "tv.fill",
        "house.fill", "building.fill", "bolt.fill", "building.2.fill",
        "wrench.and.screwdriver.fill", "flame.fill", "wifi",
        "gamecontroller.fill", "film.fill", "figure.run", "music.note",
        "person.2.fill", "dice.fill", "ticket.fill",
        "stethoscope", "pills.fill", "heart.text.square.fill",
        "mouth.fill", "heart.circle.fill",
        "book.fill", "graduationcap.fill", "character.book.fill",
        "doc.text.fill", "pencil",
        "phone.fill", "shippingbox.fill", "person.crop.circle.fill",
        "gift.fill", "banknote.fill", "heart.fill",
        "pawprint.fill",
        "chart.line.uptrend.xyaxis", "chart.bar.fill", "percent", "coins",
        "briefcase.fill", "person.wave.2.fill", "pencil.line",
        "star.fill", "star.circle.fill", "arrow.uturn.backward.circle.fill",
        "lightbulb.fill", "leaf.fill", "tag.fill", "cart.fill",
        "creditcard.fill", "wallet.pass.fill", "calendar", "clock.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text(parentCategory == nil ? loc["categories.addCategory"] : loc["categories.addSubcategory"])
                    .font(.headline)
                Spacer()
                Button(loc["categories.add"]) {
                    if categoryVM.addCategory(
                        name: name,
                        icon: icon,
                        type: categoryType,
                        to: book,
                        parent: parentCategory
                    ) {
                        dismiss()
                    }
                }
                .disabled(name.isEmpty)
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            TextField("Category name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if let parent = parentCategory {
                HStack(spacing: 6) {
                    Image(systemName: parent.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(loc["categories.parent"] + ": \(parent.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Text("Choose Icon")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(iconOptions, id: \.self) { iconName in
                        Image(systemName: iconName)
                            .font(.callout)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(iconName == icon ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(iconName == icon ? Color.accentColor : Color(.systemGray5))
                            )
                            .scaleEffect(iconName == icon ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: icon)
                            .onTapGesture {
                                icon = iconName
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isNameFocused = true
            }
        }
        .alert(loc["categories.error"], isPresented: .constant(categoryVM.errorMessage != nil)) {
            Button(loc["categories.ok"]) { categoryVM.errorMessage = nil }
        } message: {
            Text(categoryVM.errorMessage ?? "")
        }
    }
}
