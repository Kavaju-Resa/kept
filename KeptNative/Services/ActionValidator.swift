import Foundation

struct ActionValidator: Sendable {
    var resolver = TemporalResolver()

    func validate(
        turn: AssistantTurn,
        originalText: String,
        existingReminderIDs: Set<String>,
        existingMemoryIDs: Set<String>,
        now: Date,
        defaultTime: DateComponents,
        language: String
    ) -> ActionValidationResult {
        if let clarification = turn.clarification?.trimmingCharacters(in: .whitespacesAndNewlines), !clarification.isEmpty {
            return .init(actions: [], clarification: clarification, requiresConfirmation: false)
        }

        var validated: [ValidatedAction] = []
        var confirmation = false

        for proposed in turn.actions {
            switch proposed.kind {
            case .createReminder:
                guard let title = clean(proposed.title) else {
                    return missing(language, spanish: "¿Qué quieres que te recuerde?", english: "What should I remind you about?")
                }
                do {
                    let schedule = try resolver.resolve(action: proposed, now: now, defaultTime: defaultTime)
                    if schedule.leadAlreadyPassed {
                        var immediateSchedule = schedule
                        immediateSchedule.nextReminderAt = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now
                        return .init(
                            actions: [.createReminder(title: title, sourceText: originalText, recurringKey: clean(proposed.recurringKey), schedule: immediateSchedule)],
                            clarification: language.hasPrefix("es")
                                ? "El aviso de este ciclo ya pasó. ¿Quieres que te avise ahora y mantenga los próximos ciclos?"
                                : "This cycle's alert time has passed. Should I alert you now and keep future cycles?",
                            requiresConfirmation: true
                        )
                    }
                    validated.append(.createReminder(title: title, sourceText: originalText, recurringKey: clean(proposed.recurringKey), schedule: schedule))
                } catch {
                    return missing(language, spanish: "¿Para qué fecha y hora debo programarlo?", english: "What date and time should I use?")
                }
            case .updateReminder:
                guard let id = proposed.targetID, existingReminderIDs.contains(id) else {
                    return missing(language, spanish: "¿Qué recordatorio quieres modificar?", english: "Which reminder should I change?")
                }
                let schedule = try? resolver.resolve(action: proposed, now: now, defaultTime: defaultTime)
                guard clean(proposed.title) != nil || schedule != nil else {
                    return missing(language, spanish: "¿Qué quieres cambiar?", english: "What should I change?")
                }
                validated.append(.updateReminder(id: id, title: clean(proposed.title), schedule: schedule))
            case .completeReminder:
                guard let id = proposed.targetID, existingReminderIDs.contains(id) else {
                    return missing(language, spanish: "¿Qué recordatorio has completado?", english: "Which reminder did you complete?")
                }
                validated.append(.completeReminder(id: id))
            case .deleteReminder:
                guard let id = proposed.targetID, existingReminderIDs.contains(id) else {
                    return missing(language, spanish: "¿Qué recordatorio quieres eliminar?", english: "Which reminder should I delete?")
                }
                confirmation = true
                validated.append(.deleteReminder(id: id))
            case .logMemory:
                guard let title = clean(proposed.title) else {
                    return missing(language, spanish: "¿Qué dato quieres guardar?", english: "What would you like me to remember?")
                }
                validated.append(.logMemory(text: originalText, title: title, category: clean(proposed.category) ?? "other", recurringKey: clean(proposed.recurringKey)))
            case .updateMemory:
                guard let id = proposed.targetID, existingMemoryIDs.contains(id) else {
                    return missing(language, spanish: "¿Qué recuerdo quieres modificar?", english: "Which memory should I change?")
                }
                validated.append(.updateMemory(id: id, title: clean(proposed.title), category: clean(proposed.category)))
            case .deleteMemory:
                guard let id = proposed.targetID, existingMemoryIDs.contains(id) else {
                    return missing(language, spanish: "¿Qué recuerdo quieres eliminar?", english: "Which memory should I delete?")
                }
                confirmation = true
                validated.append(.deleteMemory(id: id))
            case .updatePreference:
                guard let key = proposed.preferenceKey,
                      ["default_reminder_time", "snooze_days"].contains(key),
                      let value = clean(proposed.preferenceValue) else {
                    return missing(language, spanish: "No pude validar esa preferencia.", english: "I couldn't validate that preference.")
                }
                validated.append(.updatePreference(key: key, value: value))
            case .organizeMemories:
                confirmation = true
                validated.append(.organizeMemories)
            case .none:
                continue
            }
            confirmation = confirmation || proposed.requiresConfirmation
        }

        return .init(actions: validated, clarification: nil, requiresConfirmation: confirmation)
    }

    private func clean(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }

    private func missing(_ language: String, spanish: String, english: String) -> ActionValidationResult {
        .init(actions: [], clarification: language.hasPrefix("es") ? spanish : english, requiresConfirmation: false)
    }
}
