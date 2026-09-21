import SwiftUI
import CoreData

/// The one editor for categories: create a top-level category, a subcategory, or rename an existing one.
struct CategoryEditorView: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var categoryVM = CategoryViewModel()

    let book: Book
    let categoryType: CategoryType
    var parentCategory: Category? = nil
    var editing: Category? = nil

    @State private var name = ""
    @State private var icon = CategoryIcons.fallback

    private var isCreating: Bool { editing == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(loc["categories.categoryName"], text: $name)

                    if let parent = parentCategory {
                        LabeledContent(loc["categories.parent"]) {
                            Label(parent.name, systemImage: parent.icon)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(loc["categories.chooseIcon"]) {
                    CategoryIconGrid(selection: $icon)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc["categories.cancel"]) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? loc["categories.add"] : loc["categories.save"], action: commit)
                        .disabled(name.isEmpty)
                }
            }
            .alert(loc["categories.error"], isPresented: .constant(categoryVM.errorMessage != nil)) {
                Button(loc["categories.ok"]) { categoryVM.errorMessage = nil }
            } message: {
                Text(categoryVM.errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            guard let category = editing else { return }
            name = category.name
            icon = category.icon
        }
    }

    private var navigationTitle: String {
        if !isCreating { return loc["categories.editCategory"] }
        return parentCategory == nil ? loc["categories.addCategory"] : loc["categories.addSubcategory"]
    }

    private func commit() {
        if let category = editing {
            if categoryVM.updateCategory(category, name: name, icon: icon) { dismiss() }
        } else if categoryVM.addCategory(
            name: name,
            icon: icon,
            type: categoryType,
            to: book,
            parent: parentCategory
        ) {
            dismiss()
        }
    }
}
