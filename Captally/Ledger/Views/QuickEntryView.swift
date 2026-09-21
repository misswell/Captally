import SwiftUI

struct QuickEntryView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @StateObject private var transactionVM = TransactionViewModel()

    @State private var showAddCategorySheet = false
    @State private var addingSubCategoryFor: Category? = nil
    @State private var showToast = false
    @State private var toastMessage = ""

    private var themeColor: Color {
        transactionVM.selectedType == .expense ? .expenseColor : .incomeColor
    }

    private var themeGradient: LinearGradient {
        transactionVM.selectedType == .expense ? Color.expenseGradient : Color.incomeGradient
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                amountCard
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

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
                    Spacer()
                    Text(loc["quickEntry.noLedger"])
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Spacer(minLength: 0)

                AmountKeyboard(
                    text: $transactionVM.amountText,
                    themeColor: themeColor,
                    onConfirm: save
                )
            }
            .overlay(alignment: .top) {
                if showToast {
                    toastView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle(loc["quickEntry.title"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        DatePicker(
                            loc["quickEntry.date"],
                            selection: $transactionVM.date,
                            displayedComponents: .date
                        )
                        .labelsHidden()

                        NavigationLink {
                            CategoryListView()
                        } label: {
                            Label(loc["quickEntry.categories"], systemImage: "folder")
                        }

                        NavigationLink {
                            NoteInputView(note: $transactionVM.note)
                        } label: {
                            Label(loc["quickEntry.note"], systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
            .sheet(isPresented: $showAddCategorySheet) {
                if let book = bookVM.currentBook {
                    QuickAddCategoryView(
                        book: book,
                        categoryType: transactionVM.selectedType == .expense ? .expense : .income,
                        parentCategory: addingSubCategoryFor
                    )
                }
            }
        }
    }

    private var toastView: some View {
        Text(toastMessage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                    )
            )
            .padding(.top, 8)
    }

    private var amountCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let book = bookVM.currentBook {
                    Menu {
                        ForEach(bookVM.books, id: \.id) { b in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    bookVM.switchBook(to: b)
                                    transactionVM.currentBook = b
                                }
                            } label: {
                                Label {
                                    Text(b.name)
                                } icon: {
                                    Image(systemName: b.id == book.id ? "checkmark.circle.fill" : b.icon)
                                }
                            }
                            .disabled(b.id == book.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: book.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(book.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }

                            if bookVM.books.count > 1 {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 0) {
                    typeButton(title: loc["quickEntry.expense"], isSelected: transactionVM.selectedType == .expense) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            transactionVM.selectedType = .expense
                        }
                    }

                    typeButton(title: loc["quickEntry.income"], isSelected: transactionVM.selectedType == .income) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            transactionVM.selectedType = .income
                        }
                    }
                }
                .padding(2)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Text(transactionVM.amountText.isEmpty ? "0" : transactionVM.amountText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.default, value: transactionVM.amountText)

                Spacer()

                if let category = transactionVM.selectedCategory {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.caption)
                        Text(category.name)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)

            HStack(spacing: 16) {
                dateChip
                if !transactionVM.note.isEmpty {
                    noteChip
                }
                Spacer()
            }
            .padding(.top, 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .background(themeGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: themeColor.opacity(0.25), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.3), value: transactionVM.selectedType)
    }

    private func typeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(isSelected ? .white.opacity(0.2) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private var dateChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 10))
            Text(transactionVM.date.formatted(.dateTime.month().day()))
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }

    private var noteChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "pencil")
                .font(.system(size: 10))
            Text(transactionVM.note)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }

    private func save() {
        let savedAmount = transactionVM.amountText
        if transactionVM.saveTransaction() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            toastMessage = String(format: loc["quickEntry.saved"], "¥\(savedAmount)")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showToast = false
                }
            }
        }
    }
}

struct NoteInputView: View {
    @Binding var note: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        Form {
            Section {
                TextField(loc["quickEntry.notePlaceholder"], text: $note)
                    .font(.body)
            }
        }
        .navigationTitle(loc["quickEntry.note"])
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(loc["quickEntry.done"]) { dismiss() }
            }
        }
    }
}
