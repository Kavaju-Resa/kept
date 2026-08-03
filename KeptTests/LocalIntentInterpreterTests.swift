import XCTest
@testable import Kept

final class LocalIntentInterpreterTests: XCTestCase {
    func testScreenshotPromptCreatesMonthlyReminderOneDayEarly() throws {
        let prompt = "El dia 5 de cada mes tengo que pagar el alquiler de mi casa. Recuerdame estos un dia antes"
        let turn = try XCTUnwrap(LocalIntentInterpreter().interpret(prompt, language: "es"))
        let action = try XCTUnwrap(turn.actions.first)

        guard case .createReminder = action.kind else {
            return XCTFail("Expected a reminder creation")
        }
        guard case .monthly = action.recurrence else {
            return XCTFail("Expected monthly recurrence")
        }
        guard case .day = action.leadUnit else {
            return XCTFail("Expected a day-based lead")
        }
        XCTAssertEqual(action.title, "Pagar el alquiler de mi casa")
        XCTAssertEqual(action.day, 5)
        XCTAssertEqual(action.leadValue, 1)
        XCTAssertNil(turn.clarification)

        let result = ActionValidator(resolver: TemporalResolver(timeZone: zone)).validate(
            turn: turn,
            originalText: prompt,
            existingReminderIDs: [],
            existingMemoryIDs: [],
            now: date(2026, 8, 3, 10),
            defaultTime: DateComponents(hour: 9),
            language: "es"
        )
        XCTAssertEqual(result.actions.count, 1)
        XCTAssertNil(result.clarification)
    }

    func testEnglishMonthlyPromptIsRecognized() throws {
        let prompt = "I have to pay rent on the 5th of every month. Remind me one day before."
        let turn = try XCTUnwrap(LocalIntentInterpreter().interpret(prompt, language: "en"))
        let action = try XCTUnwrap(turn.actions.first)
        XCTAssertEqual(action.day, 5)
        XCTAssertEqual(action.leadValue, 1)
        XCTAssertEqual(action.title, "Pay rent")
    }

    func testAmbiguousPromptStillGoesToAppleIntelligence() {
        XCTAssertNil(LocalIntentInterpreter().interpret("Recuérdamelo antes", language: "es"))
    }

    private let zone = TimeZone(identifier: "Europe/Madrid")!

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
