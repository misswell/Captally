import SwiftUI

struct SettingsView: View {
    @AppStorage("currency") private var currency = "CNY"
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        NavigationStack {
            Form {
                Section(loc["settings.general"]) {
                    Picker(loc["settings.currency"], selection: $currency) {
                        Text(loc["settings.cny"]).tag("CNY")
                        Text(loc["settings.usd"]).tag("USD")
                        Text(loc["settings.eur"]).tag("EUR")
                        Text(loc["settings.jpy"]).tag("JPY")
                    }

                    Picker(loc["settings.language"], selection: $loc.language) {
                        ForEach(Language.allCases, id: \.self) { language in
                            Text(language.nativeDisplayName).tag(language)
                        }
                    }
                }

                Section(loc["settings.data"]) {
                    NavigationLink {
                        CategoryListView()
                    } label: {
                        Label(loc["settings.categories"], systemImage: "folder")
                    }

                    NavigationLink {
                        DataExportView()
                    } label: {
                        Label(loc["settings.exportData"], systemImage: "square.and.arrow.up")
                    }
                }

                Section(loc["settings.about"]) {
                    LabeledContent(loc["settings.version"], value: AppInfo.version)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(loc["settings.privacyPolicy"], systemImage: "lock.shield")
                    }
                }
            }
            .navigationTitle(loc["settings.title"])
        }
    }
}

struct PrivacyPolicyView: View {
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        List {
            Section {
                Label(loc["settings.iCloudSync"], systemImage: "icloud")
                Text(loc["settings.iCloudSyncDesc"])
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Label(loc["settings.dataSecurity"], systemImage: "checkmark.shield")
                Text(loc["settings.dataSecurityDesc"])
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(loc["settings.privacyPolicy"])
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataExportView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var loc: LocalizationManager
    @State private var exportText = ""
    @State private var showShareSheet = false

    var body: some View {
        List {
            if let book = bookVM.currentBook {
                Section {
                    Button(loc["settings.exportCSV"]) {
                        exportCSV(for: book)
                        showShareSheet = true
                    }

                    Button(loc["settings.exportJSON"]) {
                        exportJSON(for: book)
                        showShareSheet = true
                    }
                }

                if !exportText.isEmpty {
                    Section(loc["settings.preview"]) {
                        Text(exportText)
                            .font(.caption)
                            .monospaced()
                    }
                }
            }
        }
        .navigationTitle(loc["settings.exportData"])
        .sheet(isPresented: $showShareSheet) {
            if let data = exportText.data(using: .utf8) {
                ShareSheet(items: [data])
            }
        }
    }

    private func exportCSV(for book: Book) {
        let transactions = sortedTransactions(in: book)

        var csv = "\(loc["stats.date"]),\(loc["categories.type"]),\(loc["stats.category"]),\(loc["ledgers.amount"]),\(loc["quickEntry.note"])\n"
        for transaction in transactions {
            let type = transaction.transactionType == .expense ? loc["categories.expense"] : loc["categories.income"]
            csv += "\(transaction.date.formatted(.dateTime.year().month().day())),\(type),\(transaction.category?.name ?? ""),\((transaction.amount as Decimal).currencyString),\(transaction.note ?? "")\n"
        }
        exportText = csv
    }

    private func exportJSON(for book: Book) {
        let items = sortedTransactions(in: book).map { transaction in
            [
                "date": transaction.date.formatted(.dateTime.year().month().day()),
                "type": transaction.transactionType == .expense ? "expense" : "income",
                "category": transaction.category?.name ?? "",
                "amount": String(describing: transaction.amount),
                "note": transaction.note ?? "",
            ] as [String: Any]
        }

        if let data = try? JSONSerialization.data(withJSONObject: items, options: .prettyPrinted) {
            exportText = String(data: data, encoding: .utf8) ?? ""
        }
    }

    private func sortedTransactions(in book: Book) -> [Transaction] {
        ((book.transactions?.allObjects as? [Transaction]) ?? []).sorted { $0.date > $1.date }
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
