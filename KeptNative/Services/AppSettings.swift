import AppKit
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) } }
    var confirmBeforeQuit: Bool { didSet { defaults.set(confirmBeforeQuit, forKey: Keys.confirmBeforeQuit) } }
    var proactiveSuggestions: Bool { didSet { defaults.set(proactiveSuggestions, forKey: Keys.proactiveSuggestions) } }
    var patternLeadDays: Int { didSet { defaults.set(patternLeadDays, forKey: Keys.patternLeadDays) } }
    var accentName: String { didSet { defaults.set(accentName, forKey: Keys.accentName) } }
    var appearanceName: String { didSet { defaults.set(appearanceName, forKey: Keys.appearanceName) } }
    var interfaceLanguage: String { didSet { defaults.set(interfaceLanguage, forKey: Keys.interfaceLanguage) } }
    var defaultReminderTime: String { didSet { defaults.set(defaultReminderTime, forKey: Keys.defaultReminderTime) } }
    var snoozeDays: Int { didSet { defaults.set(snoozeDays, forKey: Keys.snoozeDays) } }
    var dictationLanguage: String { didSet { defaults.set(dictationLanguage, forKey: Keys.dictationLanguage) } }
    var dictationHotkey: String { didSet { defaults.set(dictationHotkey, forKey: Keys.dictationHotkey) } }
    var hideCompletedTasks: Bool { didSet { defaults.set(hideCompletedTasks, forKey: Keys.hideCompletedTasks) } }

    private init() {
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        confirmBeforeQuit = defaults.object(forKey: Keys.confirmBeforeQuit) as? Bool ?? true
        proactiveSuggestions = defaults.object(forKey: Keys.proactiveSuggestions) as? Bool ?? true
        patternLeadDays = defaults.object(forKey: Keys.patternLeadDays) as? Int ?? 3
        accentName = defaults.string(forKey: Keys.accentName) ?? "system"
        appearanceName = defaults.string(forKey: Keys.appearanceName) ?? "system"
        interfaceLanguage = defaults.string(forKey: Keys.interfaceLanguage) ?? "auto"
        defaultReminderTime = defaults.string(forKey: Keys.defaultReminderTime) ?? "09:00"
        snoozeDays = defaults.object(forKey: Keys.snoozeDays) as? Int ?? 1
        dictationLanguage = defaults.string(forKey: Keys.dictationLanguage) ?? "auto"
        dictationHotkey = defaults.string(forKey: Keys.dictationHotkey) ?? ""
        hideCompletedTasks = defaults.object(forKey: Keys.hideCompletedTasks) as? Bool ?? true
    }

    func applyLaunchAtLogin() throws {
        if launchAtLogin {
            if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }

    var defaultTimeComponents: DateComponents {
        let parts = defaultReminderTime.split(separator: ":").compactMap { Int($0) }
        return DateComponents(hour: parts.first ?? 9, minute: parts.count > 1 ? parts[1] : 0)
    }

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let confirmBeforeQuit = "confirmBeforeQuit"
        static let proactiveSuggestions = "proactiveSuggestions"
        static let patternLeadDays = "patternLeadDays"
        static let accentName = "accentName"
        static let appearanceName = "appearanceName"
        static let interfaceLanguage = "interfaceLanguage"
        static let defaultReminderTime = "defaultReminderTime"
        static let snoozeDays = "snoozeDays"
        static let dictationLanguage = "dictationLanguage"
        static let dictationHotkey = "dictationHotkey"
        static let hideCompletedTasks = "hideCompletedTasks"
    }
}
