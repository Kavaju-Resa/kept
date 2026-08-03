// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import AppKit
import Foundation

extension Notification.Name {
    static let keptDictationHotkeyPressed = Notification.Name("kept.dictationHotkeyPressed")
    static let keptDictationHotkeyReleased = Notification.Name("kept.dictationHotkeyReleased")
}

enum DictationHotkey: String, CaseIterable, Identifiable {
    case disabled
    case function
    case rightOption
    case rightControl
    case rightShift
    case rightCommand

    var id: String { rawValue }

    var keyCode: UInt16? {
        switch self {
        case .disabled: nil
        case .function: 63
        case .rightOption: 61
        case .rightControl: 62
        case .rightShift: 60
        case .rightCommand: 54
        }
    }

    var modifier: NSEvent.ModifierFlags? {
        switch self {
        case .disabled: nil
        case .function: .function
        case .rightOption: .option
        case .rightControl: .control
        case .rightShift: .shift
        case .rightCommand: .command
        }
    }

    func displayName(language: String) -> String {
        let spanish = language == "es"
        return switch self {
        case .disabled: spanish ? "Desactivado" : "Disabled"
        case .function: "Fn"
        case .rightOption: spanish ? "Opción derecha (⌥)" : "Right Option (⌥)"
        case .rightControl: spanish ? "Control derecho (⌃)" : "Right Control (⌃)"
        case .rightShift: spanish ? "Mayúsculas derecha (⇧)" : "Right Shift (⇧)"
        case .rightCommand: spanish ? "Comando derecho (⌘)" : "Right Command (⌘)"
        }
    }

    func isPressed(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Bool? {
        guard let configuredKeyCode = self.keyCode,
              let modifier,
              keyCode == configuredKeyCode else { return nil }
        return modifierFlags.intersection(.deviceIndependentFlagsMask).contains(modifier)
    }
}

@MainActor
final class DictationHotkeyMonitor {
    static let shared = DictationHotkeyMonitor()

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var activeHotkey: DictationHotkey?

    private init() {}

    func start() {
        guard localMonitor == nil, globalMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            DictationHotkeyMonitor.shared.handle(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags
            )
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .flagsChanged,
            handler: Self.handleGlobalEvent
        )
    }

    func stop() {
        releaseIfNeeded()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }

    func configurationDidChange() {
        releaseIfNeeded()
    }

    private nonisolated static func handleGlobalEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let rawFlags = event.modifierFlags.rawValue
        Task { @MainActor in
            DictationHotkeyMonitor.shared.handle(
                keyCode: keyCode,
                modifierFlags: NSEvent.ModifierFlags(rawValue: rawFlags)
            )
        }
    }

    private func handle(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        // Modifier flags are aggregate: if both Option keys are held, releasing
        // the configured right key still leaves `.option` set. A second
        // flagsChanged event for the same physical key is therefore the most
        // reliable release signal.
        if activeHotkey?.keyCode == keyCode {
            releaseIfNeeded()
            return
        }

        guard activeHotkey == nil,
              let configured = DictationHotkey(rawValue: AppSettings.shared.dictationHotkey),
              configured != .disabled,
              configured.isPressed(keyCode: keyCode, modifierFlags: modifierFlags) == true else { return }

        activeHotkey = configured
        NotificationCenter.default.post(name: .keptDictationHotkeyPressed, object: nil)
    }

    private func releaseIfNeeded() {
        guard activeHotkey != nil else { return }
        activeHotkey = nil
        NotificationCenter.default.post(name: .keptDictationHotkeyReleased, object: nil)
    }
}
