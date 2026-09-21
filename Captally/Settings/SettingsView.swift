import SwiftUI

struct SettingsView: View {
    @AppStorage("currency") private var currency = "CNY"
    @AppStorage("defaultBookId") private var defaultBookId = ""
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
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.nativeDisplayName).tag(lang)
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

                    NavigationLink {
                        DataManageView()
                    } label: {
                        Label(loc["settings.dataManagement"], systemImage: "externaldrive")
                    }
                }

                Section(loc["settings.about"]) {
                    HStack {
                        Text(loc["settings.version"])
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Text(loc["settings.privacyPolicy"])
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(loc["settings.title"])
        }
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
        let transactions = (book.transactions?.allObjects as? [Transaction]) ?? []
            .sorted { $0.date > $1.date }

        var csv = "\(loc["stats.date"]),\(loc["categories.type"]),\(loc["stats.category"]),\(loc["ledgers.amount"]),\(loc["quickEntry.note"])\n"
        for t in transactions {
            let type = t.transactionType == .expense ? loc["categories.expense"] : loc["categories.income"]
            let category = t.category?.name ?? ""
            let amount = (t.amount as Decimal).currencyString
            let note = t.note ?? ""
            csv += "\(t.date.formatted(.dateTime.year().month().day())),\(type),\(category),\(amount),\(note)\n"
        }
        exportText = csv
    }

    private func exportJSON(for book: Book) {
        let transactions = (book.transactions?.allObjects as? [Transaction]) ?? []
            .sorted { $0.date > $1.date }

        var items: [[String: Any]] = []
        for t in transactions {
            items.append([
                "date": t.date.formatted(.dateTime.year().month().day()),
                "type": t.transactionType == .expense ? "expense" : "income",
                "category": t.category?.name ?? "",
                "amount": String(describing: t.amount),
                "note": t.note ?? ""
            ])
        }

        if let data = try? JSONSerialization.data(withJSONObject: items, options: .prettyPrinted) {
            exportText = String(data: data, encoding: .utf8) ?? ""
        }
    }
}

struct DataManageView: View {
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc["settings.iCloudSync"])
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(loc["settings.iCloudSyncDesc"])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc["settings.dataSecurity"])
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(loc["settings.dataSecurityDesc"])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(loc["settings.dataManagement"])
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
