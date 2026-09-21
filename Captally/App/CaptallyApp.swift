import SwiftUI

@main
struct CaptallyApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var bookVM: BookViewModel
    @StateObject private var locManager = LocalizationManager()

    init() {
        let environment = AppEnvironment()
        #if DEBUG
        DemoDataSeeder.seedIfNeeded(using: environment.persistence)
        #endif
        _environment = StateObject(wrappedValue: environment)
        _bookVM = StateObject(wrappedValue: BookViewModel(persistenceController: environment.persistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, environment.persistence.viewContext)
                .environmentObject(environment)
                .environmentObject(bookVM)
                .environmentObject(locManager)
                .task {
                    _ = await NotificationService.shared.requestAuthorization()
                }
        }
    }
}
