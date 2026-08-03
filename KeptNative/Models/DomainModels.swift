// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import Foundation
import SwiftData

@Model
final class ReminderItem {
    @Attribute(.unique) var id: String
    var title: String
    var sourceText: String?
    var createdAt: Date
    var eventAt: Date
    var timeZoneID: String
    var recurrenceRaw: String
    var recurrenceInterval: Int
    var recurrenceWeekdaysCSV: String?
    var recurrenceDayOfMonth: Int?
    var leadValue: Int
    var leadUnitRaw: String
    var nextReminderAt: Date
    var statusRaw: String
    var notifiedAt: Date?
    var completedAt: Date?
    var lastCompletedOccurrenceAt: Date?
    var sourceRaw: String
    var recurringKey: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        sourceText: String? = nil,
        createdAt: Date = .now,
        eventAt: Date,
        timeZoneID: String = TimeZone.current.identifier,
        recurrence: RecurrenceFrequency = .none,
        recurrenceInterval: Int = 1,
        recurrenceWeekdays: [Int] = [],
        recurrenceDayOfMonth: Int? = nil,
        leadValue: Int = 0,
        leadUnit: LeadUnit = .minute,
        nextReminderAt: Date? = nil,
        status: ReminderStatus = .pending,
        notifiedAt: Date? = nil,
        completedAt: Date? = nil,
        source: String = "chat",
        recurringKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceText = sourceText
        self.createdAt = createdAt
        self.eventAt = eventAt
        self.timeZoneID = timeZoneID
        self.recurrenceRaw = recurrence.rawValue
        self.recurrenceInterval = max(1, recurrenceInterval)
        self.recurrenceWeekdaysCSV = recurrenceWeekdays.isEmpty ? nil : recurrenceWeekdays.map(String.init).joined(separator: ",")
        self.recurrenceDayOfMonth = recurrenceDayOfMonth
        self.leadValue = max(0, leadValue)
        self.leadUnitRaw = leadUnit.rawValue
        self.nextReminderAt = nextReminderAt ?? eventAt
        self.statusRaw = status.rawValue
        self.notifiedAt = notifiedAt
        self.completedAt = completedAt
        self.sourceRaw = source
        self.recurringKey = recurringKey
    }

    var recurrence: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    var leadUnit: LeadUnit {
        get { LeadUnit(rawValue: leadUnitRaw) ?? .minute }
        set { leadUnitRaw = newValue.rawValue }
    }

    var status: ReminderStatus {
        get { ReminderStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var recurrenceWeekdays: [Int] {
        recurrenceWeekdaysCSV?.split(separator: ",").compactMap { Int($0) } ?? []
    }
}

@Model
final class MemoryItem {
    @Attribute(.unique) var id: String
    var text: String
    var title: String?
    var sourceText: String?
    var category: String
    var recurringKey: String?
    var eventDate: Date
    var createdAt: Date
    var kindRaw: String
    var preferenceKey: String?
    var preferenceValue: String?

    init(
        id: String = UUID().uuidString,
        text: String,
        title: String? = nil,
        sourceText: String? = nil,
        category: String = "other",
        recurringKey: String? = nil,
        eventDate: Date = .now,
        createdAt: Date = .now,
        kind: String = "log",
        preferenceKey: String? = nil,
        preferenceValue: String? = nil
    ) {
        self.id = id
        self.text = text
        self.title = title
        self.sourceText = sourceText
        self.category = category
        self.recurringKey = recurringKey
        self.eventDate = eventDate
        self.createdAt = createdAt
        self.kindRaw = kind
        self.preferenceKey = preferenceKey
        self.preferenceValue = preferenceValue
    }
}

@Model
final class ConversationMessage {
    @Attribute(.unique) var id: String
    var roleRaw: String
    var text: String
    var createdAt: Date
    var kindRaw: String
    var clarificationPrompt: String?
    var clarificationOptionsJSON: String?
    var clarificationResolvedValue: String?
    var clarificationExpired: Bool

    init(
        id: String = UUID().uuidString,
        role: String,
        text: String,
        createdAt: Date = .now,
        kind: String = "text",
        clarificationPrompt: String? = nil,
        clarificationOptionsJSON: String? = nil,
        clarificationResolvedValue: String? = nil,
        clarificationExpired: Bool = false
    ) {
        self.id = id
        self.roleRaw = role
        self.text = text
        self.createdAt = createdAt
        self.kindRaw = kind
        self.clarificationPrompt = clarificationPrompt
        self.clarificationOptionsJSON = clarificationOptionsJSON
        self.clarificationResolvedValue = clarificationResolvedValue
        self.clarificationExpired = clarificationExpired
    }
}

@Model
final class PatternRecord {
    @Attribute(.unique) var recurringKey: String
    var statusRaw: String
    var discoveryNotifiedAt: Date?
    var lastRemindedCycle: String?

    init(recurringKey: String, status: String = "active", discoveryNotifiedAt: Date? = nil, lastRemindedCycle: String? = nil) {
        self.recurringKey = recurringKey
        self.statusRaw = status
        self.discoveryNotifiedAt = discoveryNotifiedAt
        self.lastRemindedCycle = lastRemindedCycle
    }
}
