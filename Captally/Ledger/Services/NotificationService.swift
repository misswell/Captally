import Foundation
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleBudgetOverrunNotification(bookName: String, budgetAmount: Decimal, spentAmount: Decimal) {
        let content = UNMutableNotificationContent()
        content.title = LocalizationManager.localized("notification.budgetOverrun")
        content.body = "\(bookName) \(String(format: LocalizationManager.localized("notification.overBudgetBy"), (spentAmount - budgetAmount).currencyString))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "budget_\(bookName)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = LocalizationManager.localized("notification.dailyReminder")
        content.body = LocalizationManager.localized("notification.reminderBody")
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 22
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }
}
