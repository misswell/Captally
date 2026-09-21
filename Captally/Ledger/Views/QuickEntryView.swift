import SwiftUI

struct QuickEntryView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @StateObject private var transactionVM = TransactionViewModel()
    @Binding var selectedTab: Int

    @State private var showAddCategorySheet = false
    @State private var addingSubCategoryFor: Category? = nil
    @State private var showToast = false
    @State private var toastMessage = ""

    private var themeColor: Color {
        transactionVM.selectedType == .expense ? .expenseColor : .incomeColor
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Metrics.s) {
                header
                amountBlock
                metaRow

                if let book = bookVM.currentBook {
                    GridCategoryView(
                        book: book,
                        categoryType: transactionVM.selectedType == .expense ? .expense : .income,
                        selectedCategory: $transactionVM.selectedCategory,
                        themeColor: themeColor,
                        onAddTopLevel: {
                            addingSubCategoryFor = nil
                            showAddCategorySheet = true
                        },
                        onAddSubLevel: { parent in
                            addingSubCategoryFor = parent
                            showAddCategorySheet = true
                        }
                    )
                } else {
                    noLedger
                }

                AmountKeyboard(
                    text: $transactionVM.amountText,
                    themeColor: themeColor,
                    isConfirmEnabled: transactionVM.canSave,
                    onConfirm: save
                )
            }
            .padding(.top, Metrics.s)
            .overlay(alignment: .top) {
                if showToast {
                    toastView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle(loc["quickEntry.title"])
            .navigationBarTitleDisplayMode(.inline)
            .collapsingTopBarOnScroll()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CategoryListView()
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                    }
                }
            }
            .onChange(of: bookVM.currentBook) { _, newBook in
                transactionVM.currentBook = newBook
            }
            .onChange(of: transactionVM.selectedType) { _, _ in
                transactionVM.selectedCategory = nil
            }
            .onAppear {
                transactionVM.currentBook = bookVM.currentBook
            }
            .task(id: showToast) {
                guard showToast else { return }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) { showToast = false }
            }
            .sheet(isPresented: $showAddCategorySheet) {
                if let book = bookVM.currentBook {
                    CategoryEditorView(
                        book: book,
                        categoryType: transactionVM.selectedType == .expense ? .expense : .income,
                        parentCategory: addingSubCategoryFor
                    )
                }
            }
            .sensoryFeedback(trigger: showToast) { _, shown in shown ? .success : nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Metrics.s) {
            if let book = bookVM.currentBook {
                bookMenu(book)
            }
            typePicker
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private func bookMenu(_ book: Book) -> some View {
        Menu {
            ForEach(bookVM.books, id: \.id) { candidate in
                Button {
                    bookVM.switchBook(to: candidate)
                    transactionVM.currentBook = candidate
                } label: {
                    Label {
                        Text(candidate.name)
                    } icon: {
                        Image(systemName: candidate.id == book.id ? "checkmark.circle.fill" : candidate.icon)
                    }
                }
                .disabled(candidate.id == book.id)
            }
        } label: {
            HStack(spacing: Metrics.xs) {
                Image(systemName: book.icon)
                    .foregroundStyle(Color.brand)
                Text(book.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if bookVM.books.count > 1 {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, Metrics.m)
            .frame(height: Metrics.rowHeight)
            .glassKey(radius: Metrics.chipHeight)
        }
        .buttonStyle(.plain)
    }

    private var typePicker: some View {
        Picker(loc["quickEntry.title"], selection: $transactionVM.selectedType) {
            Text(loc["quickEntry.expense"]).tag(TransactionType.expense)
            Text(loc["quickEntry.income"]).tag(TransactionType.income)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .tint(themeColor)
    }

    // MARK: - Amount

    private var amountBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("¥")
                .font(.title2.weight(.semibold))
                .foregroundStyle(themeColor)

            Text(transactionVM.amountText.isEmpty ? "0" : transactionVM.amountText)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(transactionVM.amountText.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: transactionVM.amountText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private var metaRow: some View {
        GlassGroup {
            HStack(spacing: Metrics.s) {
                dateControl
                noteControl
                Spacer(minLength: Metrics.s)
                if let category = transactionVM.selectedCategory {
                    categoryChip(category)
                }
            }
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private var dateControl: some View {
        Menu {
            DatePicker(
                loc["quickEntry.date"],
                selection: $transactionVM.date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        } label: {
            metaLabel(systemImage: "calendar", title: transactionVM.date.formatted(.dateTime.month(.abbreviated).day()))
        }
        .buttonStyle(.plain)
    }

    private var noteControl: some View {
        NavigationLink {
            NoteInputView(note: $transactionVM.note)
        } label: {
            metaLabel(
                systemImage: "note.text",
                title: transactionVM.note.isEmpty ? loc["quickEntry.note"] : transactionVM.note
            )
        }
        .buttonStyle(.plain)
    }

    private func metaLabel(systemImage: String, title: String) -> some View {
        HStack(spacing: Metrics.xs) {
            Image(systemName: systemImage)
                .font(.footnote)
            Text(title)
                .font(.footnote)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, Metrics.m)
        .frame(height: Metrics.chipHeight)
        .glassPill()
    }

    private func categoryChip(_ category: Category) -> some View {
        HStack(spacing: Metrics.xs) {
            Image(systemName: category.icon)
                .font(.footnote)
            Text(category.name)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(themeColor)
        .padding(.horizontal, Metrics.m)
        .frame(height: Metrics.chipHeight)
        .glassPill(tint: themeColor.opacity(0.3))
    }

    // MARK: - States

    private var noLedger: some View {
        ContentUnavailableView {
            Label(loc["bills.noLedger"], systemImage: "book.closed")
        } description: {
            Text(loc["quickEntry.noLedger"])
        } actions: {
            Button(loc["quickEntry.createLedger"]) { selectedTab = 3 }
                .primaryAction(tint: .brand)
        }
        .frame(maxHeight: .infinity)
    }

    private var toastView: some View {
        Text(toastMessage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Metrics.l)
            .padding(.vertical, Metrics.m)
            .glassSurface(Metrics.l)
            .padding(.top, Metrics.xs)
    }

    // MARK: - Actions

    private func save(_ amountText: String) {
        transactionVM.amountText = amountText
        guard transactionVM.saveTransaction() else { return }

        toastMessage = String(format: loc["quickEntry.saved"], "¥\(amountText)")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showToast = true }
    }
}

struct NoteInputView: View {
    @Binding var note: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        Form {
            Section {
                TextField(loc["quickEntry.notePlaceholder"], text: $note, axis: .vertical)
                    .lineLimit(1...6)
            }
        }
        .navigationTitle(loc["quickEntry.note"])
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(loc["quickEntry.done"]) { dismiss() }
            }
        }
    }
}
