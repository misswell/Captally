import SwiftUI
import CoreData

struct CategoryListView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @StateObject private var categoryVM = CategoryViewModel()

    @State private var selectedType: CategoryType = .expense
    @State private var isSorting = false
    @State private var editor: EditorTarget?

    /// Which flavour of the editor the sheet should open: a new top-level category, a new
    /// subcategory, or a rename of an existing one.
    private struct EditorTarget: Identifiable {
        let id = UUID()
        let type: CategoryType
        var parent: Category? = nil
        var editing: Category? = nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(loc["categories.type"], selection: $selectedType) {
                    Text(loc["categories.expense"]).tag(CategoryType.expense)
                    Text(loc["categories.income"]).tag(CategoryType.income)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.s)
                .padding(.bottom, Metrics.xs)

                if let book = bookVM.currentBook {
                    categoryList(in: book)
                } else {
                    ContentUnavailableView {
                        Label(loc["bills.noLedger"], systemImage: "tray")
                    } description: {
                        Text(loc["bills.noLedgerDesc"])
                    }
                }
            }
            .navigationTitle(loc["categories.title"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isSorting.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel(isSorting ? loc["categories.done"] : loc["categories.sortCategories"])
                    .disabled(bookVM.currentBook == nil)

                    Button {
                        editor = EditorTarget(type: selectedType)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(loc["categories.addCategory"])
                    .disabled(isSorting || bookVM.currentBook == nil)
                }
            }
            .sheet(item: $editor) { target in
                if let book = bookVM.currentBook {
                    CategoryEditorView(
                        book: book,
                        categoryType: target.type,
                        parentCategory: target.parent,
                        editing: target.editing
                    )
                }
            }
            .alert(loc["categories.error"], isPresented: .constant(categoryVM.errorMessage != nil)) {
                Button(loc["categories.ok"]) { categoryVM.errorMessage = nil }
            } message: {
                Text(categoryVM.errorMessage ?? "")
            }
        }
    }

    // MARK: - List

    @ViewBuilder
    private func categoryList(in book: Book) -> some View {
        let topLevel = categoryVM.getCategories(for: book, type: selectedType)
        let subLevel = categoryVM.getCategories(for: book, type: selectedType, topLevel: false)

        if topLevel.isEmpty && subLevel.isEmpty {
            ContentUnavailableView {
                Label(loc["categories.empty"], systemImage: "folder.badge.plus")
            } description: {
                Text(loc["categories.emptyHint"])
            } actions: {
                Button(loc["categories.addCategory"]) {
                    editor = EditorTarget(type: selectedType)
                }
                .primaryAction(tint: .brand)
            }
        } else {
            List {
                if !topLevel.isEmpty {
                    Section {
                        ForEach(topLevel, id: \.id) { category in
                            categoryRow(category, parent: nil)
                                .swipeActions(edge: .leading) {
                                    Button(loc["categories.addSubcategory"]) {
                                        editor = EditorTarget(type: selectedType, parent: category)
                                    }
                                    .tint(.brand)
                                }
                        }
                        .onMove { source, destination in
                            categoryVM.moveCategory(topLevel, from: source, to: destination)
                        }
                        .onDelete { offsets in
                            offsets.map { topLevel[$0] }.forEach { categoryVM.deleteCategory($0) }
                        }
                    } header: {
                        sectionHeader(loc["categories.topLevel"], count: topLevel.count)
                    }
                }

                if !subLevel.isEmpty {
                    Section {
                        ForEach(subLevel, id: \.id) { category in
                            categoryRow(category, parent: topLevel.first { $0.id == category.parentId })
                        }
                        .onMove { source, destination in
                            categoryVM.moveCategory(subLevel, from: source, to: destination)
                        }
                        .onDelete { offsets in
                            offsets.map { subLevel[$0] }.forEach { categoryVM.deleteCategory($0) }
                        }
                    } header: {
                        sectionHeader(loc["categories.subLevel"], count: subLevel.count)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(isSorting ? .active : .inactive))
            .animation(.snappy, value: isSorting)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        Text("\(title) · \(count)")
    }

    private func categoryRow(_ category: Category, parent: Category?) -> some View {
        let tint = Color.categoryColor(for: Int(category.sortOrder))

        return Button {
            editor = EditorTarget(type: category.categoryType, parent: parent, editing: category)
        } label: {
            HStack(spacing: Metrics.s) {
                Image(systemName: category.icon)
                    .font(.body)
                    .frame(width: 34, height: 34)
                    .foregroundStyle(tint)
                    .background(
                        tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                    if let parent {
                        Text(parent.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if category.isSystem {
                        Text(loc["categories.default"])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: Metrics.xs)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSorting)
        .deleteDisabled(!category.canDelete)
    }
}
