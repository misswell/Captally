import SwiftUI
import CoreData

struct GridCategoryView: View {
    @EnvironmentObject var loc: LocalizationManager
    let book: Book
    let categoryType: CategoryType
    @Binding var selectedCategory: Category?
    var themeColor: Color = .brand
    let onAddTopLevel: () -> Void
    let onAddSubLevel: (Category) -> Void

    @State private var selectedParent: Category?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.l) {
                if topLevelCategories.isEmpty {
                    ContentUnavailableView {
                        Label(loc["component.noCategories"], systemImage: "square.dashed")
                    } actions: {
                        Button(loc["component.addCategory"], action: onAddTopLevel)
                    }
                } else {
                    section(
                        loc["component.topLevelCategory"],
                        categories: topLevelCategories,
                        selectedID: selectedParent?.id,
                        onSelect: select(parent:),
                        onAdd: onAddTopLevel
                    )

                    if let parent = selectedParent {
                        section(
                            loc["component.subLevelCategory"],
                            categories: subCategories(of: parent),
                            selectedID: selectedCategory?.id,
                            onSelect: { selectedCategory = $0 },
                            onAdd: { onAddSubLevel(parent) }
                        )
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, Metrics.m)
        }
        .softTopScrollEdge()
        .onAppear { autoSelectFirstCategory() }
        .onChange(of: categoryType) { _, _ in resetSelection() }
        .onChange(of: book.id) { _, _ in resetSelection() }
    }

    private var allCategories: [Category] {
        (book.categories?.allObjects as? [Category] ?? []).filter { $0.categoryType == categoryType }
    }

    private var topLevelCategories: [Category] {
        allCategories.filter { $0.isTopLevel }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func subCategories(of parent: Category) -> [Category] {
        allCategories.filter { $0.parentId == parent.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func section(
        _ title: String,
        categories: [Category],
        selectedID: UUID?,
        onSelect: @escaping (Category) -> Void,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.s), count: 4),
                spacing: Metrics.s
            ) {
                ForEach(categories, id: \.id) { category in
                    CategoryGridItem(
                        category: category,
                        isSelected: selectedID == category.id,
                        themeColor: themeColor,
                        action: { onSelect(category) }
                    )
                }

                AddCategoryButton(action: onAdd)
            }
        }
        .animation(.snappy, value: selectedID)
    }

    private func select(parent: Category) {
        selectedParent = parent
        selectedCategory = subCategories(of: parent).isEmpty ? parent : nil
    }

    private func resetSelection() {
        selectedParent = nil
        selectedCategory = nil
        autoSelectFirstCategory()
    }

    private func autoSelectFirstCategory() {
        guard let first = topLevelCategories.first, selectedParent == nil else { return }
        select(parent: first)
    }
}

struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool
    var themeColor: Color = .brand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Metrics.xs) {
                Image(systemName: category.icon)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected ? themeColor : Color(.secondarySystemFill),
                        in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    )

                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? themeColor : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

struct AddCategoryButton: View {
    @EnvironmentObject var loc: LocalizationManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Metrics.xs) {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .foregroundStyle(.quaternary)
                    )

                Text(loc["component.add"])
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc["component.addCategory"])
    }
}
