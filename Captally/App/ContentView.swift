import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var loc: LocalizationManager
    @State private var selectedTab = AppTab.record.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            QuickEntryView(selectedTab: $selectedTab)
                .tabItem { Label(loc["tab.record"], systemImage: "plus.circle") }
                .tag(AppTab.record.rawValue)

            BillListView(selectedTab: $selectedTab)
                .tabItem { Label(loc["tab.bills"], systemImage: "list.bullet") }
                .tag(AppTab.bills.rawValue)

            StatisticsView(selectedTab: $selectedTab)
                .tabItem { Label(loc["tab.stats"], systemImage: "chart.pie") }
                .tag(AppTab.stats.rawValue)

            BookManagementView()
                .tabItem { Label(loc["tab.ledgers"], systemImage: "book") }
                .tag(AppTab.ledgers.rawValue)

            SettingsView()
                .tabItem { Label(loc["tab.settings"], systemImage: "gearshape") }
                .tag(AppTab.settings.rawValue)
        }
        .tint(.brand)
        .task { await environment.capture.start() }
        .onDisappear { environment.capture.stop() }
    }
}

/// Tab identities. Raw values are the `selection` payload, so reordering this enum reorders
/// the tab bar.
enum AppTab: Int {
    case record
    case bills
    case stats
    case ledgers
    case settings
}
