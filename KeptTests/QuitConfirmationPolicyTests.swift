// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

@testable import Kept
import Testing

struct QuitConfirmationPolicyTests {
    @Test func normalQuitStillRequiresConfirmation() {
        #expect(QuitConfirmationPolicy.shouldConfirmQuit(
            confirmBeforeQuit: true,
            alreadyConfirmed: false,
            relaunchingForUpdate: false
        ))
    }

    @Test func updateRelaunchSkipsDuplicateConfirmation() {
        #expect(!QuitConfirmationPolicy.shouldConfirmQuit(
            confirmBeforeQuit: true,
            alreadyConfirmed: false,
            relaunchingForUpdate: true
        ))
    }

    @Test func disabledOrAlreadyConfirmedQuitSkipsConfirmation() {
        #expect(!QuitConfirmationPolicy.shouldConfirmQuit(
            confirmBeforeQuit: false,
            alreadyConfirmed: false,
            relaunchingForUpdate: false
        ))
        #expect(!QuitConfirmationPolicy.shouldConfirmQuit(
            confirmBeforeQuit: true,
            alreadyConfirmed: true,
            relaunchingForUpdate: false
        ))
    }
}
