import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bookVM: BookViewModel
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var loc: LocalizationManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            QuickEntryView()
                .tabItem {
                    Label(loc["tab.record"], systemImage: "plus.circle")
                }
                .tag(0)

            BillListView()
                .tabItem {
                    Label(loc["tab.bills"], systemImage: "list.bullet")
                }
                .tag(1)

            StatisticsView()
                .tabItem {
                    Label(loc["tab.stats"], systemImage: "chart.pie")
                }
                .tag(2)

            BookManagementView()
                .tabItem {
                    Label(loc["tab.ledgers"], systemImage: "book")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label(loc["tab.settings"], systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(.accentColor)
        .task { await environment.capture.start() }
        .onDisappear { environment.capture.stop() }
    }
}

