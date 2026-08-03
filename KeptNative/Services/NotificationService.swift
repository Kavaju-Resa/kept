// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import Foundation
import UserNotifications

extension Notification.Name {
    static let keptCompleteReminder = Notification.Name("kept.completeReminder")
    static let keptSnoozeReminder = Notification.Name("kept.snoozeReminder")
    static let keptOpenReminder = Notification.Name("kept.openReminder")
    static let keptOpenMemory = Notification.Name("kept.openMemory")
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private let resolver = TemporalResolver()

    override private init() {
        super.init()
        center.delegate = self
    }

    func configure() async {
        let done = UNNotificationAction(identifier: "DONE", title: "Completar", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Posponer", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "REMINDER", actions: [done, snooze], intentIdentifiers: [], options: [])
        ])
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(_ reminder: ReminderItem) async {
        await remove(reminderID: reminder.id)
        guard reminder.status == .pending else { return }
        let now = Date.now
        var dates = resolver.upcomingReminderDates(for: reminder, after: now, limit: reminder.recurrence == .none ? 1 : 12)
        if reminder.nextReminderAt > now,
           dates.first.map({ abs($0.timeIntervalSince(reminder.nextReminderAt)) > 1 }) ?? true {
            dates.insert(reminder.nextReminderAt, at: 0)
            if reminder.recurrence == .none { dates = Array(dates.prefix(1)) }
            else { dates = Array(dates.prefix(12)) }
        }
        for date in dates {
            let content = UNMutableNotificationContent()
            content.title = "Kept"
            content.body = reminder.title
            content.sound = .default
            content.categoryIdentifier = "REMINDER"
            content.userInfo = ["reminderID": reminder.id, "date": date.timeIntervalSince1970]
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let request = UNNotificationRequest(
                identifier: identifier(reminder.id, date: date),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    func remove(reminderID: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("reminder:\(reminderID):") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func schedulePattern(_ pattern: DetectedLocalPattern, leadDays: Int) async {
        guard let alertDate = Calendar.current.date(byAdding: .day, value: -max(0, leadDays), to: pattern.nextExpected), alertDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Kept"
        content.body = "\(pattern.title) may be coming up again."
        content.sound = .default
        content.userInfo = ["patternKey": pattern.recurringKey]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let request = UNNotificationRequest(
            identifier: "pattern:\(pattern.recurringKey):\(Int(alertDate.timeIntervalSince1970))",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.notification.request.content.userInfo["patternKey"] as? String != nil {
            await MainActor.run { NotificationCenter.default.post(name: .keptOpenMemory, object: nil) }
            return
        }
        guard let id = response.notification.request.content.userInfo["reminderID"] as? String else { return }
        let name: Notification.Name = switch response.actionIdentifier {
        case "DONE": .keptCompleteReminder
        case "SNOOZE": .keptSnoozeReminder
        default: .keptOpenReminder
        }
        await MainActor.run {
            NotificationCenter.default.post(name: name, object: id)
        }
    }

    private func identifier(_ id: String, date: Date) -> String {
        "reminder:\(id):\(Int(date.timeIntervalSince1970))"
    }
}
