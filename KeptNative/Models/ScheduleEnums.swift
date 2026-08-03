import Foundation

enum ReminderStatus: String, Codable, CaseIterable, Sendable {
    case pending, done, cancelled
}

enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case none, daily, weekly, monthly, yearly
}

enum LeadUnit: String, Codable, CaseIterable, Sendable {
    case minute, hour, day, week, month
}

struct ReminderScheduleInput: Sendable, Equatable {
    var title: String
    var eventAt: Date
    var recurrence: RecurrenceFrequency = .none
    var recurrenceInterval: Int = 1
    var recurrenceWeekdays: [Int] = []
    var recurrenceDayOfMonth: Int?
    var leadValue: Int = 0
    var leadUnit: LeadUnit = .minute

    func normalized(timeZone: TimeZone) -> NormalizedReminderSchedule {
        let resolver = TemporalResolver(timeZone: timeZone)
        let calendar = resolver.calendar
        let weekdays: [Int]
        if recurrence == .weekly {
            let supplied = Set(recurrenceWeekdays.filter { (1...7).contains($0) })
            weekdays = supplied.isEmpty ? [calendar.isoWeekday(for: eventAt)] : supplied.sorted()
        } else {
            weekdays = []
        }

        let dayOfMonth: Int?
        if recurrence == .monthly {
            dayOfMonth = min(31, max(1, recurrenceDayOfMonth ?? calendar.component(.day, from: eventAt)))
        } else {
            dayOfMonth = nil
        }

        let safeLead = max(0, leadValue)
        return NormalizedReminderSchedule(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            eventAt: eventAt,
            timeZoneID: timeZone.identifier,
            recurrence: recurrence,
            recurrenceInterval: max(1, recurrenceInterval),
            recurrenceWeekdays: weekdays,
            recurrenceDayOfMonth: dayOfMonth,
            leadValue: safeLead,
            leadUnit: leadUnit,
            nextReminderAt: resolver.reminderDate(for: eventAt, leadValue: safeLead, leadUnit: leadUnit) ?? eventAt
        )
    }
}

struct NormalizedReminderSchedule: Sendable, Equatable {
    let title: String
    let eventAt: Date
    let timeZoneID: String
    let recurrence: RecurrenceFrequency
    let recurrenceInterval: Int
    let recurrenceWeekdays: [Int]
    let recurrenceDayOfMonth: Int?
    let leadValue: Int
    let leadUnit: LeadUnit
    let nextReminderAt: Date
}
