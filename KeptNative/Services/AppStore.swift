import AppKit
import Foundation
import FoundationModels
import Observation
import SwiftData

enum AppTab: String, CaseIterable, Identifiable {
    case chat, memory
    var id: String { rawValue }
}

@MainActor
@Observable
final class AppStore {
    let container: ModelContainer
    let context: ModelContext
    let settings = AppSettings.shared

    var selectedTab: AppTab = .chat
    var isThinking = false
    var assistantAvailability: AssistantService.Availability = .unavailable("checking")
    var pendingActions: [ValidatedAction] = []
    var confirmationPrompt: String?

    private let assistant = AssistantService()
    private let validator = ActionValidator()
    private let notifications = NotificationService.shared
    private var observers: [NSObjectProtocol] = []

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        observeNotifications()
    }

    func start() async {
        UpdateService.shared.start()
        assistantAvailability = await assistant.availability()
        await notifications.configure()
        await rescheduleAll()
        await scheduleDetectedPatterns()
        let snapshot = makeSnapshot(language: resolvedLanguage(for: ""))
        await assistant.prewarm(snapshot: snapshot)
        try? settings.applyLaunchAtLogin()
    }

    func send(_ rawText: String) async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        let language = resolvedLanguage(for: text)
        context.insert(ConversationMessage(role: "user", text: text))
        try? context.save()

        guard case .available = assistantAvailability else {
            appendAssistant(language == "es"
                ? "Apple Intelligence no está disponible. Puedes seguir usando tareas y memorias manualmente."
                : "Apple Intelligence is unavailable. You can keep using tasks and memories manually.")
            return
        }

        isThinking = true
        defer { isThinking = false }
        do {
            let reminders = try context.fetch(FetchDescriptor<ReminderItem>())
            let memories = try context.fetch(FetchDescriptor<MemoryItem>())
            let turn = try await assistant.respond(to: text, snapshot: makeSnapshot(language: language))
            let result = validator.validate(
                turn: turn,
                originalText: text,
                existingReminderIDs: Set(reminders.map(\.id)),
                existingMemoryIDs: Set(memories.map(\.id)),
                now: .now,
                defaultTime: settings.defaultTimeComponents,
                language: language
            )

            if let clarification = result.clarification, !result.actions.isEmpty, result.requiresConfirmation {
                pendingActions = result.actions
                confirmationPrompt = clarification
                appendAssistant(clarification, kind: "clarification", clarificationPrompt: clarification)
            } else if let clarification = result.clarification {
                appendAssistant(clarification, kind: "clarification", clarificationPrompt: clarification)
            } else if result.requiresConfirmation, !result.actions.isEmpty {
                pendingActions = result.actions
                confirmationPrompt = language == "es" ? "Esta acción modifica o elimina datos. ¿Quieres continuar?" : "This action changes or deletes data. Continue?"
                appendAssistant(confirmationPrompt ?? turn.reply)
            } else if !result.actions.isEmpty {
                let count = try await execute(result.actions)
                appendAssistant(successMessage(count: count, language: language))
            } else {
                appendAssistant(turn.reply)
            }
        } catch {
            appendAssistant(assistantErrorMessage(for: error, language: language))
        }
    }

    func confirmPending() async {
        let actions = pendingActions
        pendingActions = []
        confirmationPrompt = nil
        guard !actions.isEmpty else { return }
        do {
            let count = try await execute(actions)
            appendAssistant(successMessage(count: count, language: resolvedLanguage(for: "")))
        } catch {
            appendAssistant("No pude completar la acción: \(error.localizedDescription)")
        }
    }

    func cancelPending() {
        pendingActions = []
        confirmationPrompt = nil
        appendAssistant(resolvedLanguage(for: "") == "es" ? "No he realizado ningún cambio." : "I didn't make any changes.")
    }

    func createManualReminder(_ input: ReminderScheduleInput) async {
        let schedule = input.normalized(timeZone: .current)
        let item = ReminderItem(
            title: schedule.title,
            eventAt: schedule.eventAt,
            timeZoneID: schedule.timeZoneID,
            recurrence: schedule.recurrence,
            recurrenceInterval: schedule.recurrenceInterval,
            recurrenceWeekdays: schedule.recurrenceWeekdays,
            recurrenceDayOfMonth: schedule.recurrenceDayOfMonth,
            leadValue: schedule.leadValue,
            leadUnit: schedule.leadUnit,
            nextReminderAt: schedule.nextReminderAt,
            source: "manual"
        )
        context.insert(item)
        try? context.save()
        await notifications.schedule(item)
    }

    func updateReminder(_ item: ReminderItem, with input: ReminderScheduleInput) async {
        let timeZone = TimeZone(identifier: item.timeZoneID) ?? .current
        let schedule = input.normalized(timeZone: timeZone)
        item.title = schedule.title
        item.eventAt = schedule.eventAt
        item.timeZoneID = schedule.timeZoneID
        item.recurrence = schedule.recurrence
        item.recurrenceInterval = schedule.recurrenceInterval
        item.recurrenceWeekdaysCSV = schedule.recurrenceWeekdays.isEmpty
            ? nil
            : schedule.recurrenceWeekdays.map(String.init).joined(separator: ",")
        item.recurrenceDayOfMonth = schedule.recurrenceDayOfMonth
        item.leadValue = schedule.leadValue
        item.leadUnit = schedule.leadUnit
        item.nextReminderAt = schedule.nextReminderAt
        item.notifiedAt = nil
        try? context.save()
        await notifications.schedule(item)
    }

    func completeReminder(id: String) async {
        guard let item = reminder(id: id) else { return }
        if item.recurrence == .none {
            item.status = .done
            item.completedAt = .now
            await notifications.remove(reminderID: id)
        } else if let next = TemporalResolver(timeZone: TimeZone(identifier: item.timeZoneID) ?? .current).nextOccurrence(after: item.eventAt, for: item) {
            item.lastCompletedOccurrenceAt = item.eventAt
            item.eventAt = next
            item.nextReminderAt = TemporalResolver(timeZone: TimeZone(identifier: item.timeZoneID) ?? .current)
                .reminderDate(for: next, leadValue: item.leadValue, leadUnit: item.leadUnit) ?? next
            item.notifiedAt = nil
            await notifications.schedule(item)
        }
        try? context.save()
    }

    func deleteReminder(_ item: ReminderItem) async {
        await notifications.remove(reminderID: item.id)
        context.delete(item)
        try? context.save()
    }

    func snoozeReminder(id: String) async {
        guard let item = reminder(id: id) else { return }
        item.nextReminderAt = Calendar.current.date(byAdding: .day, value: settings.snoozeDays, to: .now) ?? .now
        try? context.save()
        await notifications.schedule(item)
    }

    func deleteMemory(_ item: MemoryItem) {
        context.delete(item)
        try? context.save()
    }

    func openAppleIntelligenceSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!)
    }

    private func execute(_ actions: [ValidatedAction]) async throws -> Int {
        var changed = 0
        for action in actions {
            switch action {
            case .createReminder(let title, let sourceText, let recurringKey, let schedule):
                let item = ReminderItem(
                    title: title,
                    sourceText: sourceText,
                    eventAt: schedule.eventAt,
                    timeZoneID: schedule.timeZoneID,
                    recurrence: schedule.recurrence,
                    recurrenceInterval: schedule.recurrenceInterval,
                    recurrenceWeekdays: schedule.recurrenceWeekdays,
                    recurrenceDayOfMonth: schedule.recurrenceDayOfMonth,
                    leadValue: schedule.leadValue,
                    leadUnit: schedule.leadUnit,
                    nextReminderAt: schedule.nextReminderAt,
                    recurringKey: recurringKey
                )
                context.insert(item)
                try context.save()
                await notifications.schedule(item)
                changed += 1
            case .updateReminder(let id, let title, let schedule):
                guard let item = reminder(id: id) else { continue }
                if let title { item.title = title }
                if let schedule {
                    item.eventAt = schedule.eventAt
                    item.nextReminderAt = schedule.nextReminderAt
                    item.timeZoneID = schedule.timeZoneID
                    item.recurrence = schedule.recurrence
                    item.recurrenceInterval = schedule.recurrenceInterval
                    item.recurrenceDayOfMonth = schedule.recurrenceDayOfMonth
                    item.leadValue = schedule.leadValue
                    item.leadUnit = schedule.leadUnit
                }
                try context.save()
                await notifications.schedule(item)
                changed += 1
            case .completeReminder(let id):
                await completeReminder(id: id)
                changed += 1
            case .deleteReminder(let id):
                if let item = reminder(id: id) { await deleteReminder(item); changed += 1 }
            case .logMemory(let text, let title, let category, let recurringKey):
                context.insert(MemoryItem(text: text, title: title, sourceText: text, category: category, recurringKey: recurringKey))
                changed += 1
            case .updateMemory(let id, let title, let category):
                if let item = memory(id: id) {
                    if let title { item.title = title }
                    if let category { item.category = category }
                    changed += 1
                }
            case .deleteMemory(let id):
                if let item = memory(id: id) { context.delete(item); changed += 1 }
            case .updatePreference(let key, let value):
                if key == "default_reminder_time" { settings.defaultReminderTime = value }
                if key == "snooze_days", let days = Int(value) { settings.snoozeDays = max(1, days) }
                changed += 1
            case .organizeMemories:
                changed += try await organizeMemoriesWithAppleIntelligence()
            }
        }
        try context.save()
        await scheduleDetectedPatterns()
        return changed
    }

    private func organizeMemoriesWithAppleIntelligence() async throws -> Int {
        let items = try context.fetch(FetchDescriptor<MemoryItem>()).filter { $0.kindRaw == "log" }
        let records = items.map {
            AssistantSnapshot.Record(
                id: $0.id,
                kind: "memory",
                title: $0.title ?? $0.text,
                detail: "current_category=\($0.category), text=\($0.sourceText ?? $0.text)",
                date: $0.eventDate
            )
        }
        let assignments = try await assistant.organizeMemories(records)
        let knownIDs = Set(items.map(\.id))
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var changed = 0
        for assignment in assignments where knownIDs.contains(assignment.id) {
            guard let item = byID[assignment.id] else { continue }
            let category = assignment.category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
            let title = assignment.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !category.isEmpty, category != item.category { item.category = category; changed += 1 }
            if item.title?.isEmpty != false, !title.isEmpty { item.title = title; changed += 1 }
        }
        return changed
    }

    private func reminder(id: String) -> ReminderItem? {
        let descriptor = FetchDescriptor<ReminderItem>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func memory(id: String) -> MemoryItem? {
        let descriptor = FetchDescriptor<MemoryItem>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func appendAssistant(_ text: String, kind: String = "text", clarificationPrompt: String? = nil) {
        context.insert(ConversationMessage(role: "assistant", text: text, kind: kind, clarificationPrompt: clarificationPrompt))
        try? context.save()
    }

    private func successMessage(count: Int, language: String) -> String {
        if language == "es" { return count == 1 ? "Listo. He realizado la acción." : "Listo. He realizado \(count) acciones." }
        return count == 1 ? "Done. The action is complete." : "Done. I completed \(count) actions."
    }

    private func assistantErrorMessage(for error: Error, language: String) -> String {
        let spanish = language.hasPrefix("es")
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return spanish
                ? "Ocurrió un fallo local y no realicé ningún cambio. Inténtalo de nuevo."
                : "A local error occurred and I made no changes. Please try again."
        }

        switch generationError {
        case .assetsUnavailable(_):
            return spanish
                ? "Apple Intelligence no está disponible ahora. No realicé ningún cambio."
                : "Apple Intelligence isn't available right now. I made no changes."
        case .unsupportedLanguageOrLocale(_):
            return spanish
                ? "Apple Intelligence no admite este idioma o configuración regional. No realicé ningún cambio."
                : "Apple Intelligence doesn't support this language or locale. I made no changes."
        case .guardrailViolation(_), .refusal(_, _):
            return spanish
                ? "Apple Intelligence rechazó este mensaje. No realicé ningún cambio."
                : "Apple Intelligence declined this message. I made no changes."
        default:
            return spanish
                ? "Apple Intelligence tuvo un fallo temporal. No realicé ningún cambio; inténtalo de nuevo."
                : "Apple Intelligence had a temporary error. I made no changes; please try again."
        }
    }

    private func makeSnapshot(language: String) -> AssistantSnapshot {
        let reminders = (try? context.fetch(FetchDescriptor<ReminderItem>())) ?? []
        let memories = (try? context.fetch(FetchDescriptor<MemoryItem>())) ?? []
        let messages = ((try? context.fetch(FetchDescriptor<ConversationMessage>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []).suffix(12)
        let records = reminders.map {
            AssistantSnapshot.Record(id: $0.id, kind: "reminder", title: $0.title, detail: "status=\($0.statusRaw), recurrence=\($0.recurrenceRaw)", date: $0.eventAt)
        } + memories.filter { $0.kindRaw == "log" }.map {
            AssistantSnapshot.Record(id: $0.id, kind: "memory", title: $0.title ?? $0.text, detail: "category=\($0.category), text=\($0.text)", date: $0.eventDate)
        }
        let recent = messages.map { "\($0.roleRaw): \($0.text)" }
        return AssistantSnapshot(records: records.sorted { $0.date > $1.date }, recentConversation: recent, language: language, defaultReminderTime: settings.defaultReminderTime)
    }

    private func resolvedLanguage(for text: String) -> String {
        if settings.interfaceLanguage == "es" || settings.interfaceLanguage == "en" { return settings.interfaceLanguage }
        let lower = text.lowercased()
        let spanishSignals = [" que ", " para ", "recuérd", "tengo", "cada", "antes", "ayer", "mañana"]
        return spanishSignals.contains(where: { lower.contains($0) }) || lower.contains("ñ") ? "es" : "en"
    }

    private func rescheduleAll() async {
        let reminders = (try? context.fetch(FetchDescriptor<ReminderItem>())) ?? []
        for item in reminders where item.status == .pending { await notifications.schedule(item) }
    }

    private func observeNotifications() {
        observers.append(NotificationCenter.default.addObserver(forName: .keptCompleteReminder, object: nil, queue: .main) { [weak self] note in
            guard let id = note.object as? String else { return }
            Task { @MainActor in await self?.completeReminder(id: id) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .keptSnoozeReminder, object: nil, queue: .main) { [weak self] note in
            guard let id = note.object as? String else { return }
            Task { @MainActor in await self?.snoozeReminder(id: id) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .keptOpenReminder, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.selectedTab = .memory
                WindowRegistry.shared.showMain()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .keptOpenMemory, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.selectedTab = .memory
                WindowRegistry.shared.showMain()
            }
        })
    }

    private func scheduleDetectedPatterns() async {
        guard settings.proactiveSuggestions else { return }
        let memories = (try? context.fetch(FetchDescriptor<MemoryItem>())) ?? []
        for pattern in PatternService().detect(in: memories) {
            await notifications.schedulePattern(pattern, leadDays: settings.patternLeadDays)
        }
    }
}
