// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import Foundation

struct DetectedLocalPattern: Equatable, Sendable {
    var recurringKey: String
    var title: String
    var intervalDays: Int
    var nextExpected: Date
}

struct PatternService: Sendable {
    func detect(in memories: [MemoryItem], now: Date = .now) -> [DetectedLocalPattern] {
        let logs = memories.filter { $0.kindRaw == "log" && $0.recurringKey?.isEmpty == false }
        let groups = Dictionary(grouping: logs) { $0.recurringKey! }
        return groups.compactMap { key, values in
            let ordered = values.sorted { $0.eventDate < $1.eventDate }
            guard ordered.count >= 3 else { return nil }
            let intervals = zip(ordered, ordered.dropFirst()).map {
                max(1, Calendar.current.dateComponents([.day], from: $0.eventDate, to: $1.eventDate).day ?? 1)
            }.sorted()
            let median = intervals[intervals.count / 2]
            let tolerance = max(2, Int(Double(median) * 0.35))
            guard intervals.allSatisfy({ abs($0 - median) <= tolerance }),
                  let last = ordered.last,
                  let next = Calendar.current.date(byAdding: .day, value: median, to: last.eventDate),
                  next > now else { return nil }
            return DetectedLocalPattern(
                recurringKey: key,
                title: last.title ?? last.text,
                intervalDays: median,
                nextExpected: next
            )
        }
    }
}
