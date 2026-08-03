// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import AppKit
import XCTest
@testable import Kept

final class DictationHotkeyTests: XCTestCase {
    func testRightOptionMatchesOnlyItsPhysicalKeyCode() {
        XCTAssertEqual(
            DictationHotkey.rightOption.isPressed(keyCode: 61, modifierFlags: .option),
            true
        )
        XCTAssertEqual(
            DictationHotkey.rightOption.isPressed(keyCode: 61, modifierFlags: []),
            false
        )
        XCTAssertNil(
            DictationHotkey.rightOption.isPressed(keyCode: 58, modifierFlags: .option)
        )
    }

    func testDisabledHotkeyNeverMatches() {
        XCTAssertNil(
            DictationHotkey.disabled.isPressed(keyCode: 63, modifierFlags: .function)
        )
    }

    func testEveryEnabledHotkeyHasAUniquePhysicalKeyCode() throws {
        let enabled = DictationHotkey.allCases.filter { $0 != .disabled }
        let keyCodes = try enabled.map { try XCTUnwrap($0.keyCode) }
        XCTAssertEqual(Set(keyCodes).count, enabled.count)
    }
}
