// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import AppKit
import Observation
import SwiftUI

extension Notification.Name {
    static let keptOpenSettings = Notification.Name("kept.openSettings")
}

enum KeptWindowRole { case main, settings }

@MainActor
final class WindowRegistry {
    static let shared = WindowRegistry()
    weak var main: NSWindow?
    weak var settings: NSWindow?

    func register(_ window: NSWindow, role: KeptWindowRole) {
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.minSize = role == .main ? NSSize(width: 420, height: 580) : NSSize(width: 760, height: 680)
        switch role {
        case .main: main = window
        case .settings: settings = window
        }
    }

    func showMain() {
        main?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        syncDock()
    }

    func syncDock() {
        let visible = [main, settings].contains { $0?.isVisible == true }
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
        if visible { NSApp.activate() }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let role: KeptWindowRole

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { WindowRegistry.shared.register(window, role: role) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window { WindowRegistry.shared.register(window, role: role) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var quittingAfterConfirmation = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.didMiniaturizeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.didDeminiaturizeNotification, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowRegistry.shared.showMain()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !quittingAfterConfirmation, AppSettings.shared.confirmBeforeQuit else { return .terminateNow }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit Kept?"
        alert.informativeText = "Kept must remain open to manage reminders in the background."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Quit")
        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        quittingAfterConfirmation = true
        return .terminateNow
    }

    @objc private func windowVisibilityChanged() {
        DispatchQueue.main.async { WindowRegistry.shared.syncDock() }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "Kept")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem?.menu = makeStatusMenu()
            statusItem?.button?.performClick(nil)
        } else {
            WindowRegistry.shared.showMain()
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let open = NSMenuItem(title: "Open Kept", action: #selector(openMain), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        updates.isEnabled = UpdateService.shared.isConfigured
        menu.addItem(updates)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Kept", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    func menuDidClose(_ menu: NSMenu) { statusItem?.menu = nil }

    @objc private func openMain() { WindowRegistry.shared.showMain() }
    @objc private func openSettings() { NotificationCenter.default.post(name: .keptOpenSettings, object: nil) }
    @objc private func checkForUpdates() { UpdateService.shared.checkForUpdates() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
