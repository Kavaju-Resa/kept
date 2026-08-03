// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import XCTest
@testable import Kept

final class MemoryTimelineTests: XCTestCase {
    private let zone = TimeZone(identifier: "Europe/Madrid")!

    func testClassifiesOverdueTodayUpcomingAndPrevious() {
        let now = date(2026, 8, 3, 12)
        let calendar = calendar()
        let overdue = reminder("overdue", event: date(2026, 8, 2, 9))
        let today = reminder("today", event: date(2026, 8, 3, 18))
        let upcoming = reminder("upcoming", event: date(2026, 8, 4, 8))
        let previous = MemoryItem(id: "previous", text: "Previous", eventDate: date(2026, 8, 1, 10))

        let timeline = MemoryTimeline(
            reminders: [today, upcoming, overdue],
            memories: [previous],
            includeCompleted: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(timeline.entries(in: .overdue).map(\.id), ["reminder:overdue"])
        XCTAssertEqual(timeline.entries(in: .today).map(\.id), ["reminder:today"])
        XCTAssertEqual(timeline.entries(in: .upcoming).map(\.id), ["reminder:upcoming"])
        XCTAssertEqual(timeline.entries(in: .previous).map(\.id), ["memory:previous"])
    }

    func testSortsFutureAscendingAndHistoryDescending() {
        let now = date(2026, 8, 3, 12)
        let timeline = MemoryTimeline(
            reminders: [
                reminder("later", event: date(2026, 8, 6, 9)),
                reminder("sooner", event: date(2026, 8, 4, 9))
            ],
            memories: [
                MemoryItem(id: "older", text: "Older", eventDate: date(2026, 7, 1, 9)),
                MemoryItem(id: "newer", text: "Newer", eventDate: date(2026, 8, 2, 9))
            ],
            includeCompleted: false,
            now: now,
            calendar: calendar()
        )

        XCTAssertEqual(timeline.entries(in: .upcoming).map(\.id), ["reminder:sooner", "reminder:later"])
        XCTAssertEqual(timeline.entries(in: .previous).map(\.id), ["memory:newer", "memory:older"])
    }

    func testCompletedTasksAreOptionalAndUseCompletionDate() {
        let completed = ReminderItem(
            id: "done",
            title: "Done",
            eventAt: date(2026, 7, 1, 9),
            status: .done,
            completedAt: date(2026, 8, 3, 11)
        )
        let completedWithoutDate = ReminderItem(
            id: "done-fallback",
            title: "Done without completion date",
            eventAt: date(2026, 7, 2, 9),
            status: .done
        )
        let hidden = MemoryTimeline(
            reminders: [completed, completedWithoutDate],
            memories: [],
            includeCompleted: false,
            now: date(2026, 8, 3, 12),
            calendar: calendar()
        )
        let visible = MemoryTimeline(
            reminders: [completed, completedWithoutDate],
            memories: [],
            includeCompleted: true,
            now: date(2026, 8, 3, 12),
            calendar: calendar()
        )

        XCTAssertTrue(hidden.isEmpty)
        XCTAssertEqual(visible.entries(in: .previous).map(\.id), ["reminder:done", "reminder:done-fallback"])
        XCTAssertEqual(visible.entries(in: .previous).first?.date, date(2026, 8, 3, 11))
        XCTAssertEqual(visible.entries(in: .previous).last?.date, date(2026, 7, 2, 9))
    }

    func testEqualDatesUseStableTypeQualifiedIdentifiers() {
        let sharedDate = date(2026, 8, 3, 15)
        let timeline = MemoryTimeline(
            reminders: [reminder("same", event: sharedDate)],
            memories: [MemoryItem(id: "same", text: "Same", eventDate: sharedDate)],
            includeCompleted: false,
            now: date(2026, 8, 3, 12),
            calendar: calendar()
        )

        XCTAssertEqual(timeline.entries(in: .today).map(\.id), ["memory:same", "reminder:same"])
    }

    private func reminder(_ id: String, event: Date) -> ReminderItem {
        ReminderItem(id: id, title: id, eventAt: event)
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
