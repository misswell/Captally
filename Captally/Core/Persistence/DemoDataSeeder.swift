import CoreData
import Foundation

#if DEBUG
/// Synthetic ledger data for Captally Lab.
///
/// Absent from Release builds entirely. Automatic seeding on first launch is off even in Debug:
/// it only runs when the process starts with `CAPTALLY_SEED_DEMO_DATA=1`. A ledger filled with
/// random amounts would silently corrupt every accuracy metric Captally reports on.
enum DemoDataSeeder {
    static let environmentKey = "CAPTALLY_SEED_DEMO_DATA"

    static var isAutoSeedAllowed: Bool {
        ProcessInfo.processInfo.environment[environmentKey] == "1"
    }

    static func seedIfNeeded(using persistence: PersistenceController) {
        guard isAutoSeedAllowed else { return }
        seed(using: persistence)
    }

    private struct Recipe {
        var categorySlot: Int
        var weekdays: Set<Int>?
        var dayOfMonth: Int?
        var amount: ClosedRange<Int>
        var noteKeys: [String]
    }

    private static let recipes: [Recipe] = [
        Recipe(categorySlot: 0, weekdays: nil, dayOfMonth: nil, amount: 15...100,
               noteKeys: ["demo.breakfast", "demo.lunch", "demo.dinner"]),
        Recipe(categorySlot: 1, weekdays: [2, 3, 4, 5, 6], dayOfMonth: nil, amount: 5...50,
               noteKeys: ["demo.bus", "demo.metro", "demo.taxi"]),
        Recipe(categorySlot: 2, weekdays: nil, dayOfMonth: nil, amount: 30...300,
               noteKeys: ["demo.grocery", "demo.dailyNecessities", "demo.clothes"]),
        Recipe(categorySlot: 3, weekdays: nil, dayOfMonth: 1, amount: 80...200,
               noteKeys: ["demo.utilities"]),
        Recipe(categorySlot: 4, weekdays: [6, 7], dayOfMonth: nil, amount: 30...200,
               noteKeys: ["demo.movie", "demo.game", "demo.party"]),
        Recipe(categorySlot: 7, weekdays: nil, dayOfMonth: 15, amount: 128...128,
               noteKeys: ["demo.phoneBill"])
    ]

    @discardableResult
    static func seed(using persistence: PersistenceController, days: Int = 90) -> Int {
        let context = persistence.viewContext
        let book = Book.create(
            in: context,
            name: LocalizationManager.localized("demo.dailyExpenses"),
            icon: "house"
        )
        Category.createDefaultCategories(for: book, in: context)

        let expenseRoots = (book.categories?.allObjects as? [Category] ?? [])
            .filter { $0.isTopLevel && $0.categoryType == .expense }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard !expenseRoots.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = Date()
        var created = 0

        for dayOffset in 0..<days {
            let date = today.adding(days: -dayOffset)
            let weekday = calendar.component(.weekday, from: date)
            let dayOfMonth = calendar.component(.day, from: date)

            for recipe in recipes {
                if let weekdays = recipe.weekdays, !weekdays.contains(weekday) { continue }
                if let day = recipe.dayOfMonth, day != dayOfMonth { continue }
                guard expenseRoots.indices.contains(recipe.categorySlot) else { continue }

                let _ = Transaction.create(
                    in: context,
                    amount: Decimal(Int.random(in: recipe.amount)),
                    type: .expense,
                    category: expenseRoots[recipe.categorySlot],
                    book: book,
                    note: recipe.noteKeys.randomElement().map(LocalizationManager.localized),
                    date: date
                )
                created += 1
            }
        }

        persistence.save()
        return created
    }
}
#endif
