// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import Foundation
import XCTest
@testable import Kept

final class PromptCorpusTests: XCTestCase {
    func testBilingualPromptCorpusWithOnDeviceModel() async throws {
        guard ProcessInfo.processInfo.environment["KEPT_RUN_MODEL_TESTS"] == "1" else {
            throw XCTSkip("Set KEPT_RUN_MODEL_TESTS=1 to run nondeterministic on-device model checks.")
        }
        let service = AssistantService()
        guard case .available = await service.availability() else {
            throw XCTSkip("Apple Intelligence is unavailable.")
        }
        let snapshot = AssistantSnapshot(records: [], recentConversation: [], language: "es", defaultReminderTime: "09:00")
        let prompts = [
            "Tengo que pagar mi alquiler el 5 de cada mes, recuérdame 3 días antes",
            "El dia 5 de cada mes tengo que pagar el alquiler de mi casa. Recuerdame estos un dia antes",
            "Recuérdame llamar a Ana mañana a las 10",
            "Ayer fui al dentista",
            "Remember that my car is parked on level B2",
            "Remind me every Friday at 5 PM to send the report",
            "No hagas nada, solo dime qué tareas tengo",
            "Borra todo",
            "Recuérdamelo antes"
        ]
        for prompt in prompts {
            let turn = try await service.respond(to: prompt, snapshot: snapshot, now: Date(timeIntervalSince1970: 1_785_752_800))
            XCTAssertFalse(turn.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(!turn.actions.isEmpty || turn.clarification != nil || !turn.reply.isEmpty)
        }
    }
}
