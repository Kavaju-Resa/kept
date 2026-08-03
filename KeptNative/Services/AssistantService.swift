// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import Foundation
import FoundationModels

struct AssistantSnapshot: Sendable {
    struct Record: Sendable {
        var id: String
        var kind: String
        var title: String
        var detail: String
        var date: Date
    }

    var records: [Record]
    var recentConversation: [String]
    var language: String
    var defaultReminderTime: String
}

@Generable
struct SearchArguments {
    @Guide(description: "Words, id, category, or date phrase to search in Kept's local records.")
    var query: String
}

struct SearchKeptTool: Tool {
    private struct RankedRecord {
        let score: Int
        let record: AssistantSnapshot.Record
    }

    let name = "search_kept"
    let description = "Search the user's local Kept reminders and memories. This tool is read-only."
    let records: [AssistantSnapshot.Record]

    func call(arguments: SearchArguments) async throws -> String {
        let terms = arguments.query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        var ranked: [RankedRecord] = []
        for record in records {
            let haystack = "\(record.id) \(record.kind) \(record.title) \(record.detail)".lowercased()
            var score = 0
            for term in terms where haystack.contains(term) {
                score += 1
            }
            if terms.isEmpty || score > 0 {
                ranked.append(RankedRecord(score: score, record: record))
            }
        }
        ranked.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.record.date > rhs.record.date
            }
            return lhs.score > rhs.score
        }

        if ranked.isEmpty { return "No matching local records." }
        return ranked.prefix(10).map { item in
            let record = item.record
            return "id=\(record.id) | kind=\(record.kind) | title=\(record.title) | date=\(record.date.ISO8601Format()) | \(record.detail)"
        }.joined(separator: "\n")
    }
}

@Generable
struct MemoryAssignment {
    @Guide(description: "An id copied exactly from the supplied memory list.")
    var id: String
    @Guide(description: "A concise lowercase English snake_case life-area category.")
    var category: String
    @Guide(description: "A short normalized title in the memory's original language.")
    var title: String
}

@Generable
struct MemoryOrganization {
    @Guide(description: "Exactly one assignment for every supplied memory id.")
    var assignments: [MemoryAssignment]
}

actor AssistantService {
    enum Availability: Equatable, Sendable {
        case available
        case unavailable(String)
    }

    private var session: LanguageModelSession?
    private var exchanges = 0
    private let localInterpreter = LocalIntentInterpreter()

    func availability() -> Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(String(describing: reason))
        }
    }

    func prewarm(snapshot: AssistantSnapshot) {
        guard case .available = availability() else { return }
        let tool = SearchKeptTool(records: snapshot.records)
        let next = makeSession(tool: tool)
        next.prewarm(promptPrefix: Prompt("Current local date and user request:"))
        session = next
        exchanges = 0
    }

    func respond(to message: String, snapshot: AssistantSnapshot, now: Date = .now) async throws -> AssistantTurn {
        guard case .available = availability() else { throw AssistantError.unavailable }
        if let localTurn = localInterpreter.interpret(message, language: snapshot.language) {
            return localTurn
        }
        if session == nil || exchanges >= 6 {
            prewarm(snapshot: snapshot)
        }
        guard let session else { throw AssistantError.unavailable }

        let prompt = makePrompt(message: message, snapshot: snapshot, now: now, includeHistory: exchanges == 0)

        do {
            let response = try await session.respond(to: prompt, generating: AssistantTurn.self)
            exchanges += 1
            return response.content
        } catch {
            guard shouldRetry(error) else { throw error }
            self.session = nil
            exchanges = 0
            let reducedSnapshot = AssistantSnapshot(
                records: Array(snapshot.records.prefix(6)),
                recentConversation: Array(snapshot.recentConversation.suffix(6)),
                language: snapshot.language,
                defaultReminderTime: snapshot.defaultReminderTime
            )
            prewarm(snapshot: reducedSnapshot)
            guard let retrySession = self.session else { throw AssistantError.unavailable }
            let retryPrompt = makePrompt(message: message, snapshot: reducedSnapshot, now: now, includeHistory: true)
            let response = try await retrySession.respond(to: retryPrompt, generating: AssistantTurn.self)
            exchanges = 1
            return response.content
        }
    }

    func organizeMemories(_ records: [AssistantSnapshot.Record]) async throws -> [MemoryAssignment] {
        guard case .available = availability() else { throw AssistantError.unavailable }
        var assignments: [MemoryAssignment] = []
        for chunkStart in stride(from: 0, to: records.count, by: 40) {
            let chunk = Array(records[chunkStart..<min(records.count, chunkStart + 40)])
            let list = chunk.map { "id=\($0.id) | title=\($0.title) | \($0.detail)" }.joined(separator: "\n")
            let organizer = LanguageModelSession(instructions: """
            Organize personal memories into a small coherent set of life-area categories.
            Keep titles in their original language. Categories must be lowercase English snake_case.
            Copy every supplied id exactly and never invent ids or facts.
            """)
            let response = try await organizer.respond(
                to: "Organize every memory below, returning exactly one assignment per id:\n\(list)",
                generating: MemoryOrganization.self
            )
            assignments.append(contentsOf: response.content.assignments)
        }
        return assignments
    }

    func translate(_ text: String, request: TranslationRequest) async throws -> String {
        guard case .available = availability() else { throw AssistantError.unavailable }
        let translator = LanguageModelSession(instructions: request.instructions)
        let response = try await translator.respond(to: Prompt(request.prompt(for: text)))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeSession(tool: SearchKeptTool) -> LanguageModelSession {
        LanguageModelSession(tools: [tool], instructions: """
        You are Kept, a private on-device personal reminder and memory assistant for macOS.
        Work in Spanish or English, matching the user. Stay focused on Kept data and actions.
        You propose structured actions but never execute or claim completion yourself.
        Prefer clarification whenever a date, target, or requested effect is ambiguous.
        Event date, recurrence cadence, and alert lead are independent concepts.
        Do not invent record ids. Use the read-only search tool when resolving references.
        Keep replies concise and natural.
        """)
    }

    private func makePrompt(message: String, snapshot: AssistantSnapshot, now: Date, includeHistory: Bool) -> String {
        let relevant = snapshot.records.prefix(10).map {
            "id=\($0.id) | \($0.kind) | \($0.title) | \($0.date.ISO8601Format())"
        }.joined(separator: "\n")
        let history = includeHistory ? snapshot.recentConversation.suffix(12).joined(separator: "\n") : "(already present in this session)"
        return """
        Current local date/time: \(now.ISO8601Format()); timezone: \(TimeZone.current.identifier).
        Default time when the user gives no clock time: \(snapshot.defaultReminderTime).
        Recent conversation (oldest first):
        \(history)

        Likely relevant local records (use search_kept if the target is not here):
        \(relevant.isEmpty ? "(none)" : relevant)

        User message: \(message)

        Return a structured plan. Separate the event date, recurrence, and alert lead. Never turn "3 days before" into "3 days from now". For recurring requests, populate the calendar components that anchor the event. Use existing ids exactly. Ask one clarification instead of guessing. Deletions and bulk organization require confirmation. A message may contain multiple actions. If this is unrelated general knowledge, reply briefly that Kept focuses on reminders and personal memories, with no action.
        """
    }

    private func shouldRetry(_ error: Error) -> Bool {
        guard let generationError = error as? LanguageModelSession.GenerationError else { return true }
        switch generationError {
        case .decodingFailure(_), .exceededContextWindowSize(_), .rateLimited(_), .concurrentRequests(_):
            return true
        case .assetsUnavailable(_), .guardrailViolation(_), .refusal(_, _), .unsupportedGuide(_), .unsupportedLanguageOrLocale(_):
            return false
        @unknown default:
            return false
        }
    }

    enum AssistantError: Error {
        case unavailable
        case emptyResponse
    }
}
