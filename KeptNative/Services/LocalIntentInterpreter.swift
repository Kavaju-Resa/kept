// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import Foundation

/// A deliberately narrow, deterministic fast path for unequivocal reminder phrases.
/// Apple Intelligence remains responsible for conversational and ambiguous requests.
struct LocalIntentInterpreter: Sendable {
    func interpret(_ message: String, language: String) -> AssistantTurn? {
        let folded = message.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: language.hasPrefix("es") ? "es" : "en")
        )

        guard containsReminderVerb(folded),
              let dayText = firstCapture(
                in: folded,
                patterns: [
                    #"(?:el\s+)?(?:dia\s+)?(\d{1,2})\s+de\s+cada\s+mes"#,
                    #"cada\s+mes\s+(?:el\s+)?(?:dia\s+)?(\d{1,2})"#,
                    #"(?:on\s+)?(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?(?:\s+day)?\s+(?:of\s+)?every\s+month"#,
                    #"every\s+month\s+(?:on\s+)?(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?"#
                ]
              ),
              let day = Int(dayText), (1...31).contains(day),
              let lead = parseLead(in: folded),
              let title = extractTitle(from: message) else {
            return nil
        }

        let spanish = language.hasPrefix("es")
        let action = AssistantAction(
            kind: .createReminder,
            targetID: nil,
            title: title,
            category: nil,
            recurringKey: recurringKey(for: title),
            year: nil,
            month: nil,
            day: day,
            weekday: nil,
            hour: nil,
            minute: nil,
            recurrence: .monthly,
            recurrenceInterval: 1,
            leadValue: lead.value,
            leadUnit: lead.unit,
            preferenceKey: nil,
            preferenceValue: nil,
            requiresConfirmation: false
        )

        return AssistantTurn(
            reply: spanish ? "Prepararé el recordatorio mensual." : "I'll prepare the monthly reminder.",
            actions: [action],
            clarification: nil
        )
    }

    private func containsReminderVerb(_ text: String) -> Bool {
        ["recuerd", "avis", "remind", "notify", "alert"].contains { text.contains($0) }
    }

    private func parseLead(in text: String) -> (value: Int, unit: ProposedLeadUnit)? {
        let patterns = [
            #"(?:recuerd\w*|avis\w*)[^.!?]*?\b(\d+|un|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez)\s+(minuto|minute|hora|hour|dia|day|semana|week|mes|month)s?\s+antes\b"#,
            #"(?:remind\w*|notif\w*|alert\w*)[^.!?]*?\b(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten)\s+(minute|hour|day|week|month)s?\s+before\b"#
        ]

        for pattern in patterns {
            guard let captures = captures(in: text, pattern: pattern), captures.count == 2,
                  let value = number(from: captures[0]),
                  let unit = unit(from: captures[1]) else { continue }
            return (value, unit)
        }

        if text.range(of: #"(?:el\s+dia|dia)\s+anterior|the\s+day\s+before"#, options: .regularExpression) != nil {
            return (1, .day)
        }
        return nil
    }

    private func extractTitle(from message: String) -> String? {
        let taskPatterns = [
            #"(?:tengo\s+que|debo|necesito)\s+(.+?)(?=[.!?]|\s+(?:recu[eé]rd\w*|av[ií]s\w*)|$)"#,
            #"(?:i\s+have\s+to|i\s+need\s+to|i\s+must)\s+(.+?)(?=[.!?]|\s+(?:remind\w*|notif\w*|alert\w*)|$)"#
        ]
        guard var title = firstCapture(in: message, patterns: taskPatterns) else { return nil }

        let temporalPatterns = [
            #"\s+(?:el\s+)?(?:día\s+)?\d{1,2}\s+de\s+cada\s+mes\b"#,
            #"\s+cada\s+mes\s+(?:el\s+)?(?:día\s+)?\d{1,2}\b"#,
            #"\s+(?:on\s+)?(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?(?:\s+day)?\s+(?:of\s+)?every\s+month\b"#
        ]
        for pattern in temporalPatterns {
            title = replacingRegex(pattern, in: title, with: "")
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !title.isEmpty else { return nil }
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    private func recurringKey(for title: String) -> String {
        let folded = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let components = folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let slug = components.prefix(6).joined(separator: "_")
        return String("monthly_\(slug)".prefix(64))
    }

    private func number(from value: String) -> Int? {
        if let number = Int(value) { return number }
        return [
            "a": 1, "an": 1, "one": 1, "un": 1, "una": 1,
            "two": 2, "dos": 2, "three": 3, "tres": 3,
            "four": 4, "cuatro": 4, "five": 5, "cinco": 5,
            "six": 6, "seis": 6, "seven": 7, "siete": 7,
            "eight": 8, "ocho": 8, "nine": 9, "nueve": 9,
            "ten": 10, "diez": 10
        ][value]
    }

    private func unit(from value: String) -> ProposedLeadUnit? {
        switch value {
        case "minuto", "minute": .minute
        case "hora", "hour": .hour
        case "dia", "day": .day
        case "semana", "week": .week
        case "mes", "month": .month
        default: nil
        }
    }

    private func firstCapture(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let value = captures(in: text, pattern: pattern)?.first { return value }
        }
        return nil
    }

    private func captures(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func replacingRegex(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)
    }
}
