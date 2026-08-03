// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import Foundation

enum TemporalResolutionError: Error, Equatable {
    case missingDate
    case invalidComponents
    case eventInPast
}

struct TemporalResolver: Sendable {
    var calendar: Calendar
    var timeZone: TimeZone

    init(timeZone: TimeZone = .current) {
        self.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    func resolve(
        action: AssistantAction,
        now: Date,
        defaultTime: DateComponents
    ) throws -> ReminderSchedule {
        let recurrence = map(action.recurrence)
        let leadUnit = map(action.leadUnit)
        let event = try nextEvent(action: action, recurrence: recurrence, now: now, defaultTime: defaultTime)
        guard event > now || recurrence != .none else { throw TemporalResolutionError.eventInPast }

        let reminder = subtract(value: action.leadValue, unit: leadUnit, from: event)
        guard let reminder else { throw TemporalResolutionError.invalidComponents }

        return ReminderSchedule(
            eventAt: event,
            nextReminderAt: reminder,
            timeZoneID: timeZone.identifier,
            recurrence: recurrence,
            recurrenceInterval: max(1, action.recurrenceInterval),
            recurrenceDayOfMonth: recurrence == .monthly ? action.day : nil,
            recurrenceWeekdays: recurrence == .weekly ? action.weekday.map { [$0] } ?? [] : [],
            leadValue: max(0, action.leadValue),
            leadUnit: leadUnit,
            leadAlreadyPassed: reminder <= now && event > now
        )
    }

    func nextOccurrence(after date: Date, for reminder: ReminderItem) -> Date? {
        switch reminder.recurrence {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: reminder.recurrenceInterval, to: date)
        case .weekly:
            let weekdays = reminder.recurrenceWeekdays.isEmpty
                ? [calendar.isoWeekday(for: date)]
                : reminder.recurrenceWeekdays.sorted()
            let currentWeekday = calendar.isoWeekday(for: date)
            if let nextWeekday = weekdays.first(where: { $0 > currentWeekday }) {
                return calendar.date(byAdding: .day, value: nextWeekday - currentWeekday, to: date)
            }
            guard let firstWeekday = weekdays.first else { return nil }
            let daysUntilNextCycle = (7 * reminder.recurrenceInterval) - (currentWeekday - firstWeekday)
            return calendar.date(byAdding: .day, value: daysUntilNextCycle, to: date)
        case .monthly:
            let targetDay = reminder.recurrenceDayOfMonth ?? calendar.component(.day, from: date)
            guard let nextMonth = calendar.date(byAdding: .month, value: reminder.recurrenceInterval, to: date) else { return nil }
            return dateInMonth(containing: nextMonth, day: targetDay, hour: calendar.component(.hour, from: date), minute: calendar.component(.minute, from: date))
        case .yearly:
            return calendar.date(byAdding: .year, value: reminder.recurrenceInterval, to: date)
        }
    }

    func reminderDate(for event: Date, leadValue: Int, leadUnit: LeadUnit) -> Date? {
        subtract(value: leadValue, unit: leadUnit, from: event)
    }

    func upcomingReminderDates(for reminder: ReminderItem, after now: Date, limit: Int = 12) -> [Date] {
        var event = reminder.eventAt
        var dates: [Date] = []
        var attempts = 0
        while dates.count < limit && attempts < 240 {
            attempts += 1
            if let alert = reminderDate(for: event, leadValue: reminder.leadValue, leadUnit: reminder.leadUnit), alert > now {
                dates.append(alert)
            }
            guard let next = nextOccurrence(after: event, for: reminder) else { break }
            event = next
        }
        return dates
    }

    private func nextEvent(
        action: AssistantAction,
        recurrence: RecurrenceFrequency,
        now: Date,
        defaultTime: DateComponents
    ) throws -> Date {
        let hour = action.hour ?? defaultTime.hour ?? 9
        let minute = action.minute ?? defaultTime.minute ?? 0

        if recurrence == .monthly, let day = action.day, action.month == nil, action.year == nil {
            var cursor = now
            for _ in 0..<24 {
                guard let candidate = dateInMonth(containing: cursor, day: day, hour: hour, minute: minute) else { break }
                if candidate > now { return candidate }
                guard let next = calendar.date(byAdding: .month, value: max(1, action.recurrenceInterval), to: cursor) else { break }
                cursor = next
            }
            throw TemporalResolutionError.invalidComponents
        }

        if let isoWeekday = action.weekday, action.day == nil, action.month == nil, action.year == nil {
            let weekday = isoWeekday == 7 ? 1 : isoWeekday + 1
            let components = DateComponents(hour: hour, minute: minute, weekday: weekday)
            guard let result = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime, direction: .forward) else {
                throw TemporalResolutionError.invalidComponents
            }
            return result
        }

        if action.day == nil, action.month == nil, action.year == nil {
            if recurrence == .daily {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = hour
                components.minute = minute
                if let today = calendar.date(from: components), today > now { return today }
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components) ?? now) else {
                    throw TemporalResolutionError.invalidComponents
                }
                return tomorrow
            }
            throw TemporalResolutionError.missingDate
        }

        var components = DateComponents()
        components.timeZone = timeZone
        components.year = action.year ?? calendar.component(.year, from: now)
        components.month = action.month ?? calendar.component(.month, from: now)
        components.day = action.day
        components.hour = hour
        components.minute = minute

        guard var result = safeDate(from: components) else { throw TemporalResolutionError.invalidComponents }
        if result <= now, action.year == nil {
            let increment: Calendar.Component = action.month == nil ? .month : .year
            guard let advanced = calendar.date(byAdding: increment, value: 1, to: result) else {
                throw TemporalResolutionError.invalidComponents
            }
            result = advanced
        }
        return result
    }

    private func safeDate(from components: DateComponents) -> Date? {
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        return dateInMonth(containing: calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now, day: day, hour: components.hour ?? 9, minute: components.minute ?? 0)
    }

    private func dateInMonth(containing reference: Date, day: Int, hour: Int, minute: Int) -> Date? {
        let base = calendar.dateComponents([.year, .month], from: reference)
        guard let interval = calendar.range(of: .day, in: .month, for: reference) else { return nil }
        var components = base
        components.day = min(max(1, day), interval.count)
        components.hour = hour
        components.minute = minute
        components.timeZone = timeZone
        return calendar.date(from: components)
    }

    private func subtract(value: Int, unit: LeadUnit, from date: Date) -> Date? {
        let component: Calendar.Component = switch unit {
        case .minute: .minute
        case .hour: .hour
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        return calendar.date(byAdding: component, value: -max(0, value), to: date)
    }

    private func map(_ value: ProposedRecurrence) -> RecurrenceFrequency {
        switch value {
        case .none: .none
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
    }

    private func map(_ value: ProposedLeadUnit) -> LeadUnit {
        switch value {
        case .minute: .minute
        case .hour: .hour
        case .day: .day
        case .week: .week
        case .month: .month
        }
    }
}

extension Calendar {
    func isoWeekday(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }
}
