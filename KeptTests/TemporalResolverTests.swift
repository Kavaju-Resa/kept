// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import XCTest
@testable import Kept

final class TemporalResolverTests: XCTestCase {
    private let zone = TimeZone(identifier: "Europe/Madrid")!

    func testMonthlyRentSeparatesEventAndLead() throws {
        let resolver = TemporalResolver(timeZone: zone)
        let now = date(2026, 8, 1, 12)
        let result = try resolver.resolve(
            action: action(day: 5, recurrence: .monthly, lead: 3),
            now: now,
            defaultTime: DateComponents(hour: 9, minute: 0)
        )

        XCTAssertEqual(result.eventAt, date(2026, 8, 5, 9))
        XCTAssertEqual(result.nextReminderAt, date(2026, 8, 2, 9))
        XCTAssertFalse(result.leadAlreadyPassed)
    }

    func testMonthlyRentAsksWhenCurrentLeadPassed() throws {
        let resolver = TemporalResolver(timeZone: zone)
        let result = try resolver.resolve(
            action: action(day: 5, recurrence: .monthly, lead: 3),
            now: date(2026, 8, 3, 12),
            defaultTime: DateComponents(hour: 9, minute: 0)
        )
        XCTAssertEqual(result.eventAt, date(2026, 8, 5, 9))
        XCTAssertTrue(result.leadAlreadyPassed)
    }

    func testDay31ClampsToLastDayOfMonth() throws {
        let resolver = TemporalResolver(timeZone: zone)
        let result = try resolver.resolve(
            action: action(day: 31, recurrence: .monthly, lead: 0),
            now: date(2027, 2, 1, 8),
            defaultTime: DateComponents(hour: 9, minute: 0)
        )
        XCTAssertEqual(result.eventAt, date(2027, 2, 28, 9))
    }

    func testWeeklyOccurrencePreservesLocalHourAcrossDST() {
        let resolver = TemporalResolver(timeZone: zone)
        let item = ReminderItem(
            title: "Weekly",
            eventAt: date(2027, 3, 22, 9),
            timeZoneID: zone.identifier,
            recurrence: .weekly,
            recurrenceInterval: 1
        )
        let next = resolver.nextOccurrence(after: item.eventAt, for: item)
        XCTAssertEqual(next, date(2027, 3, 29, 9))
    }

    private func action(day: Int, recurrence: ProposedRecurrence, lead: Int) -> AssistantAction {
        AssistantAction(
            kind: .createReminder,
            targetID: nil,
            title: "Pagar alquiler",
            category: nil,
            recurringKey: "rent_payment",
            year: nil,
            month: nil,
            day: day,
            weekday: nil,
            hour: nil,
            minute: nil,
            recurrence: recurrence,
            recurrenceInterval: 1,
            leadValue: lead,
            leadUnit: .day,
            preferenceKey: nil,
            preferenceValue: nil,
            requiresConfirmation: false
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
