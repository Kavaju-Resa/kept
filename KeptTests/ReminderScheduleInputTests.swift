import XCTest
@testable import Kept

final class ReminderScheduleInputTests: XCTestCase {
    private let zone = TimeZone(identifier: "Europe/Madrid")!

    func testNormalizesWeeklyScheduleAndCalculatesLead() {
        let input = ReminderScheduleInput(
            title: "  Revisar informe  ",
            eventAt: date(2026, 8, 5, 9),
            recurrence: .weekly,
            recurrenceInterval: 2,
            recurrenceWeekdays: [5, 1, 5, 9],
            leadValue: 2,
            leadUnit: .day
        )

        let schedule = input.normalized(timeZone: zone)

        XCTAssertEqual(schedule.title, "Revisar informe")
        XCTAssertEqual(schedule.recurrenceInterval, 2)
        XCTAssertEqual(schedule.recurrenceWeekdays, [1, 5])
        XCTAssertNil(schedule.recurrenceDayOfMonth)
        XCTAssertEqual(schedule.nextReminderAt, date(2026, 8, 3, 9))
    }

    func testDerivesMissingWeeklyDayFromEvent() {
        let schedule = ReminderScheduleInput(
            title: "Weekly",
            eventAt: date(2026, 8, 5, 9),
            recurrence: .weekly
        ).normalized(timeZone: zone)

        XCTAssertEqual(schedule.recurrenceWeekdays, [3])
    }

    func testDerivesMonthlyDayAndClampsValues() {
        let schedule = ReminderScheduleInput(
            title: "Monthly",
            eventAt: date(2026, 8, 12, 9),
            recurrence: .monthly,
            recurrenceInterval: 0,
            recurrenceDayOfMonth: 40,
            leadValue: -4,
            leadUnit: .hour
        ).normalized(timeZone: zone)

        XCTAssertEqual(schedule.recurrenceInterval, 1)
        XCTAssertEqual(schedule.recurrenceDayOfMonth, 31)
        XCTAssertEqual(schedule.leadValue, 0)
        XCTAssertEqual(schedule.nextReminderAt, schedule.eventAt)
    }

    func testWeeklyNextOccurrenceUsesAllSelectedDaysAndInterval() {
        let resolver = TemporalResolver(timeZone: zone)
        let reminder = ReminderItem(
            title: "Training",
            eventAt: date(2026, 8, 3, 9),
            timeZoneID: zone.identifier,
            recurrence: .weekly,
            recurrenceInterval: 2,
            recurrenceWeekdays: [1, 3, 5]
        )

        let wednesday = resolver.nextOccurrence(after: reminder.eventAt, for: reminder)
        let friday = wednesday.flatMap { resolver.nextOccurrence(after: $0, for: reminder) }
        let nextCycle = friday.flatMap { resolver.nextOccurrence(after: $0, for: reminder) }

        XCTAssertEqual(wednesday, date(2026, 8, 5, 9))
        XCTAssertEqual(friday, date(2026, 8, 7, 9))
        XCTAssertEqual(nextCycle, date(2026, 8, 17, 9))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
