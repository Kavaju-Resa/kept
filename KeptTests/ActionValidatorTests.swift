// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import XCTest
@testable import Kept

final class ActionValidatorTests: XCTestCase {
    func testRejectsInventedTargetID() {
        let action = AssistantAction(
            kind: .completeReminder,
            targetID: "invented",
            title: nil,
            category: nil,
            recurringKey: nil,
            year: nil,
            month: nil,
            day: nil,
            weekday: nil,
            hour: nil,
            minute: nil,
            recurrence: .none,
            recurrenceInterval: 1,
            leadValue: 0,
            leadUnit: .minute,
            preferenceKey: nil,
            preferenceValue: nil,
            requiresConfirmation: false
        )
        let result = ActionValidator().validate(
            turn: AssistantTurn(reply: "", actions: [action], clarification: nil),
            originalText: "completalo",
            existingReminderIDs: [],
            existingMemoryIDs: [],
            now: .now,
            defaultTime: DateComponents(hour: 9),
            language: "es"
        )
        XCTAssertTrue(result.actions.isEmpty)
        XCTAssertNotNil(result.clarification)
    }

    func testDeletionAlwaysRequiresConfirmation() {
        let action = AssistantAction(
            kind: .deleteReminder,
            targetID: "known",
            title: nil,
            category: nil,
            recurringKey: nil,
            year: nil,
            month: nil,
            day: nil,
            weekday: nil,
            hour: nil,
            minute: nil,
            recurrence: .none,
            recurrenceInterval: 1,
            leadValue: 0,
            leadUnit: .minute,
            preferenceKey: nil,
            preferenceValue: nil,
            requiresConfirmation: false
        )
        let result = ActionValidator().validate(
            turn: AssistantTurn(reply: "", actions: [action], clarification: nil),
            originalText: "delete it",
            existingReminderIDs: ["known"],
            existingMemoryIDs: [],
            now: .now,
            defaultTime: DateComponents(hour: 9),
            language: "en"
        )
        XCTAssertTrue(result.requiresConfirmation)
        XCTAssertEqual(result.actions.count, 1)
    }
}
