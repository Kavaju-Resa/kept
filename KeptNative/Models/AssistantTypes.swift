import Foundation
import FoundationModels

@Generable
enum ProposedActionKind {
    case createReminder
    case updateReminder
    case completeReminder
    case deleteReminder
    case logMemory
    case updateMemory
    case deleteMemory
    case updatePreference
    case organizeMemories
    case none
}

@Generable
enum ProposedRecurrence {
    case none
    case daily
    case weekly
    case monthly
    case yearly
}

@Generable
enum ProposedLeadUnit {
    case minute
    case hour
    case day
    case week
    case month
}

@Generable
struct AssistantAction {
    @Guide(description: "The requested operation. Use none when the message needs no data mutation.")
    var kind: ProposedActionKind
    @Guide(description: "Existing reminder or memory id. Never invent an id; nil for creations.")
    var targetID: String?
    @Guide(description: "Concise title in the user's language, without temporal wording.")
    var title: String?
    @Guide(description: "Normalized memory category in lowercase English snake_case.")
    var category: String?
    @Guide(description: "Stable lowercase English snake_case key for a recurring real-world action.")
    var recurringKey: String?
    @Guide(description: "Calendar year of the next event, or nil when not stated and recurrence components are sufficient.")
    var year: Int?
    @Guide(description: "Calendar month 1 through 12 for the next event, if known.")
    var month: Int?
    @Guide(description: "Day of month 1 through 31 for the event, if known.")
    var day: Int?
    @Guide(description: "ISO weekday 1 Monday through 7 Sunday, if the request uses a weekday.")
    var weekday: Int?
    @Guide(description: "Hour 0 through 23. Nil when the user gave no time.")
    var hour: Int?
    @Guide(description: "Minute 0 through 59. Nil when the user gave no time.")
    var minute: Int?
    var recurrence: ProposedRecurrence
    @Guide(description: "Positive recurrence interval, normally 1.", .range(1...100))
    var recurrenceInterval: Int
    @Guide(description: "How far before the event to alert. Zero only when the alert is at event time.", .range(0...1000))
    var leadValue: Int
    var leadUnit: ProposedLeadUnit
    @Guide(description: "Preference key; only default_reminder_time, snooze_days, or nil.")
    var preferenceKey: String?
    var preferenceValue: String?
    @Guide(description: "True only when the action is destructive or changes multiple stored records.")
    var requiresConfirmation: Bool
}

@Generable
struct AssistantTurn {
    @Guide(description: "A brief helpful reply in the same language as the user. Do not claim an action already happened.")
    var reply: String
    @Guide(description: "Zero or more independent actions extracted from the message.", .maximumCount(4))
    var actions: [AssistantAction]
    @Guide(description: "One concise question when essential information is missing or ambiguous; otherwise nil.")
    var clarification: String?
}

struct ReminderSchedule: Equatable, Sendable {
    var eventAt: Date
    var nextReminderAt: Date
    var timeZoneID: String
    var recurrence: RecurrenceFrequency
    var recurrenceInterval: Int
    var recurrenceDayOfMonth: Int?
    var recurrenceWeekdays: [Int]
    var leadValue: Int
    var leadUnit: LeadUnit
    var leadAlreadyPassed: Bool
}

enum ValidatedAction: Sendable {
    case createReminder(title: String, sourceText: String, recurringKey: String?, schedule: ReminderSchedule)
    case updateReminder(id: String, title: String?, schedule: ReminderSchedule?)
    case completeReminder(id: String)
    case deleteReminder(id: String)
    case logMemory(text: String, title: String, category: String, recurringKey: String?)
    case updateMemory(id: String, title: String?, category: String?)
    case deleteMemory(id: String)
    case updatePreference(key: String, value: String)
    case organizeMemories
}

struct ActionValidationResult: Sendable {
    var actions: [ValidatedAction]
    var clarification: String?
    var requiresConfirmation: Bool
}
