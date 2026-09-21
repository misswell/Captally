import SwiftUI
import CoreData

struct GridCategoryView: View {
    @EnvironmentObject var loc: LocalizationManager
    let book: Book
    let categoryType: CategoryType
    @Binding var selectedCategory: Category?
    var themeColor: Color = .accentColor
    let onAddTopLevel: () -> Void
    let onAddSubLevel: (Category) -> Void

    @State private var selectedParentCategory: Category? = nil

    private var allCategories: [Category] {
        (book.categories?.allObjects as? [Category] ?? [])
            .filter { $0.categoryType == categoryType }
    }

    private var topLevelCategories: [Category] {
        allCategories
            .filter { $0.isTopLevel }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if topLevelCategories.isEmpty {
                    emptyState
                } else {
                    sectionView(
                        title: loc["component.topLevelCategory"],
                        categories: topLevelCategories,
                        selectedId: selectedParentCategory?.id,
                        showAddButton: true,
                        onSelect: { category in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedParentCategory = category
                                let subCategories = allCategories.filter { $0.parentId == category.id }
                                if subCategories.isEmpty {
                                    selectedCategory = category
                                } else {
                                    selectedCategory = nil
                                }
                            }
                        },
                        onAdd: onAddTopLevel
                    )

                    if let parent = selectedParentCategory {
                        let subCategories = allCategories
                            .filter { $0.parentId == parent.id }
                            .sorted { $0.sortOrder < $1.sortOrder }

                        sectionView(
                            title: "Sub-level",
                            categories: subCategories,
                            selectedId: selectedCategory?.id,
                            showAddButton: true,
                            onSelect: { category in
                                selectedCategory = category
                            },
                            onAdd: { onAddSubLevel(parent) }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .onAppear {
            autoSelectFirstCategory()
        }
        .onChange(of: categoryType) { _, _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedParentCategory = nil
                selectedCategory = nil
            }
            autoSelectFirstCategory()
        }
        .onChange(of: book.id) { _, _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedParentCategory = nil
                selectedCategory = nil
            }
            autoSelectFirstCategory()
        }
    }

    private func autoSelectFirstCategory() {
        guard let first = topLevelCategories.first else { return }
        if selectedParentCategory == nil {
            selectedParentCategory = first
            let subs = allCategories.filter { $0.parentId == first.id }
            if subs.isEmpty {
                selectedCategory = first
            }
        }
    }

    private func sectionView(
        title: String,
        categories: [Category],
        selectedId: UUID?,
        showAddButton: Bool,
        onSelect: @escaping (Category) -> Void,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            categoryGrid(
                categories: categories,
                selectedId: selectedId,
                showAddButton: showAddButton,
                onSelect: onSelect,
                onAdd: onAdd
            )
        }
    }

    private func categoryGrid(
        categories: [Category],
        selectedId: UUID?,
        showAddButton: Bool,
        onSelect: @escaping (Category) -> Void,
        onAdd: @escaping () -> Void
    ) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let hPadding: CGFloat = 16
        let hSpacing: CGFloat = 10
        let vSpacing: CGFloat = 10
        let itemWidth: CGFloat = (screenWidth - hPadding * 2 - hSpacing * 3) / 4

        var allItems: [CategoryGridItemType] = categories.map { cat in
            .category(cat, selectedId == cat.id)
        }
        if showAddButton {
            allItems.append(.add)
        }

        let pages = chunked(allItems, size: 8)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(pages.indices, id: \.self) { pageIndex in
                    let page = pages[pageIndex]
                    let pageRows = chunked(page, size: 4)

                    VStack(alignment: .leading, spacing: vSpacing) {
                        ForEach(pageRows.indices, id: \.self) { rowIndex in
                            let row = pageRows[rowIndex]
                            HStack(spacing: hSpacing) {
                                ForEach(0..<row.count, id: \.self) { colIndex in
                                    let item = row[colIndex]
                                    switch item {
                                    case .category(let cat, let isSelected):
                                        CategoryGridItem(
                                            category: cat,
                                            isSelected: isSelected,
                                            themeColor: themeColor,
                                            itemWidth: itemWidth
                                        ) {
                                            onSelect(cat)
                                        }
                                    case .add:
                                        AddCategoryButton(
                                            itemWidth: itemWidth,
                                            onTap: onAdd
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: screenWidth - hPadding * 2)
                }
            }
            .padding(.horizontal, hPadding)
        }
    }

    private enum CategoryGridItemType: Equatable {
        case category(Category, Bool)
        case add

        static func == (lhs: CategoryGridItemType, rhs: CategoryGridItemType) -> Bool {
            switch (lhs, rhs) {
            case (.add, .add): return true
            case (.category(let a, let b), .category(let c, let d)): return a.id == c.id && b == d
            default: return false
            }
        }
    }

    private func chunked<T>(_ array: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [] }
        var result: [[T]] = []
        var current: [T] = []
        for element in array {
            current.append(element)
            if current.count == size {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(loc["component.noCategories"])
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                onAddTopLevel()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                    Text(loc["component.addCategory"])
                        .font(.subheadline)
                }
                .foregroundStyle(themeColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            Spacer()
        }
        .frame(height: 200)
    }
}

struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool
    var themeColor: Color = .accentColor
    let itemWidth: CGFloat
    let onTap: () -> Void

    @State private var isBouncing = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? themeColor : Color(.systemGray6))
                        .frame(width: 48, height: 48)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.15))
                            .frame(width: 48, height: 48)
                    }

                    Image(systemName: category.icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                }

                Text(category.name)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? themeColor : .secondary)
                    .lineLimit(1)
            }
            .frame(width: itemWidth)
        }
        .buttonStyle(.plain)
        .scaleEffect(isBouncing ? 0.92 : 1.0)
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                withAnimation(.easeIn(duration: 0.08)) {
                    isBouncing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                        isBouncing = false
                    }
                }
            }
        }
    }
}

struct AddCategoryButton: View {
    @EnvironmentObject var loc: LocalizationManager
    let itemWidth: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(.tertiary)
                        .frame(width: 48, height: 48)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(loc["component.add"])
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(width: itemWidth)
        }
        .buttonStyle(.plain)
    }
}
