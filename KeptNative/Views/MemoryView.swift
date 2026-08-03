// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import SwiftData
import SwiftUI

enum MemoryTimelineBucket: CaseIterable {
    case overdue, today, upcoming, previous
}

enum MemoryTimelineEntry: Identifiable {
    case reminder(ReminderItem)
    case memory(MemoryItem)

    var id: String {
        switch self {
        case .reminder(let item): "reminder:\(item.id)"
        case .memory(let item): "memory:\(item.id)"
        }
    }

    var date: Date {
        switch self {
        case .reminder(let item): item.status == .done ? (item.completedAt ?? item.eventAt) : item.eventAt
        case .memory(let item): item.eventDate
        }
    }
}

struct MemoryTimeline {
    private var entriesByBucket: [MemoryTimelineBucket: [MemoryTimelineEntry]]

    init(
        reminders: [ReminderItem],
        memories: [MemoryItem],
        includeCompleted: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        var result = Dictionary(uniqueKeysWithValues: MemoryTimelineBucket.allCases.map { ($0, [MemoryTimelineEntry]()) })
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now

        let reminderEntries = reminders
            .filter { $0.status == .pending || (includeCompleted && $0.status == .done) }
            .map(MemoryTimelineEntry.reminder)
        let memoryEntries = memories
            .filter { $0.kindRaw == "log" }
            .map(MemoryTimelineEntry.memory)

        for entry in reminderEntries + memoryEntries {
            let bucket: MemoryTimelineBucket
            if case .reminder(let reminder) = entry, reminder.status == .done {
                bucket = .previous
            } else if case .reminder(let reminder) = entry,
                      reminder.status == .pending,
                      reminder.eventAt < startOfToday {
                bucket = .overdue
            } else if entry.date < startOfToday {
                bucket = .previous
            } else if entry.date < startOfTomorrow {
                bucket = .today
            } else {
                bucket = .upcoming
            }
            result[bucket, default: []].append(entry)
        }

        for bucket in MemoryTimelineBucket.allCases {
            result[bucket]?.sort { lhs, rhs in
                if lhs.date == rhs.date { return lhs.id < rhs.id }
                return bucket == .previous ? lhs.date > rhs.date : lhs.date < rhs.date
            }
        }
        entriesByBucket = result
    }

    func entries(in bucket: MemoryTimelineBucket) -> [MemoryTimelineEntry] {
        entriesByBucket[bucket] ?? []
    }

    var isEmpty: Bool {
        MemoryTimelineBucket.allCases.allSatisfy { entries(in: $0).isEmpty }
    }
}

struct MemoryView: View {
    @Environment(AppStore.self) private var store
    @Query(sort: \MemoryItem.eventDate, order: .reverse) private var memories: [MemoryItem]
    @Query(sort: \ReminderItem.eventAt) private var reminders: [ReminderItem]
    @State private var selectedMemory: MemoryItem?
    @State private var selectedReminder: ReminderItem?
    @State private var creatingReminder = false
    @State private var deleting: MemoryTimelineEntry?

    var body: some View {
        @Bindable var settings = store.settings
        let copy = resolvedCopy(store.settings)
        let logs = memories.filter { $0.kindRaw == "log" }
        let pendingCount = reminders.filter { $0.status == .pending }.count
        let timeline = MemoryTimeline(
            reminders: reminders,
            memories: memories,
            includeCompleted: !store.settings.hideCompletedTasks
        )

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(copy.memory).font(.title2.weight(.semibold))
                    Spacer()
                    if reminders.contains(where: { $0.status == .done }) {
                        Button {
                            settings.hideCompletedTasks.toggle()
                        } label: {
                            Image(systemName: settings.hideCompletedTasks ? "checkmark.circle" : "checkmark.circle.fill")
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        .help(settings.hideCompletedTasks ? copy.showCompleted : copy.hideCompleted)
                    }
                }
                HStack(spacing: 8) {
                    Text(copy.memoriesSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(pendingCount) \(copy.pendingSummary) · \(logs.count) \(copy.memoriesSummary)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .capsule)
                }
            }
            .frame(maxWidth: KeptTheme.narrowColumn)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)

            ScrollView {
                GlassEffectContainer(spacing: KeptTheme.glassSpacing) {
                    LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                        if timeline.isEmpty {
                            ContentUnavailableView(copy.noTimelineItems, systemImage: "brain.head.profile")
                                .padding(.top, 90)
                        }
                        ForEach(MemoryTimelineBucket.allCases, id: \.self) { bucket in
                            let entries = timeline.entries(in: bucket)
                            if !entries.isEmpty {
                                Section {
                                    ForEach(entries) { entry in
                                        timelineRow(entry, copy: copy, overdue: bucket == .overdue)
                                    }
                                } header: {
                                    KeptSectionTitle(title(for: bucket, copy: copy), count: entries.count)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: KeptTheme.narrowColumn)
                .padding(16)
                .frame(maxWidth: .infinity)
            }

            Button { creatingReminder = true } label: {
                Label(copy.addTask, systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 8)
                    .frame(height: 34)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .padding(.bottom, 14)
        }
        .sheet(isPresented: $creatingReminder) { ReminderEditor(item: nil) }
        .sheet(item: $selectedReminder) { ReminderEditor(item: $0) }
        .sheet(item: $selectedMemory) { MemoryEditor(item: $0) }
        .alert(deleteTitle(copy), isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )) {
            Button(copy.cancel, role: .cancel) { deleting = nil }
            Button(copy.delete, role: .destructive) {
                guard let deleting else { return }
                switch deleting {
                case .reminder(let item): Task { await store.deleteReminder(item) }
                case .memory(let item): store.deleteMemory(item)
                }
                self.deleting = nil
            }
        } message: {
            Text(deleteMessage)
        }
    }

    @ViewBuilder
    private func timelineRow(_ entry: MemoryTimelineEntry, copy: Copy, overdue: Bool) -> some View {
        switch entry {
        case .reminder(let item): reminderRow(item, copy: copy, overdue: overdue)
        case .memory(let item): memoryRow(item, copy: copy)
        }
    }

    private func reminderRow(_ item: ReminderItem, copy: Copy, overdue: Bool) -> some View {
        let completed = item.status == .done
        return HStack(alignment: .top, spacing: 10) {
            if completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.green)
                    .frame(width: 24, height: 30)
            } else {
                Button { Task { await store.completeReminder(id: item.id) } } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 24, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(overdue ? Color.orange : Color.secondary)
                .help(copy.language == "es" ? "Completar tarea" : "Complete task")
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title).fontWeight(.medium).strikethrough(completed).lineLimit(1)
                    if overdue {
                        Text(copy.overdue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 5) {
                    Text(item.eventAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    if item.recurrence != .none {
                        Image(systemName: "repeat").font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if item.leadValue > 0 {
                    Label(
                        "\(copy.alert) \(item.leadValue) \(copy.leadUnitName(item.leadUnit, plural: item.leadValue != 1)) \(copy.before)",
                        systemImage: "bell"
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 6)
            rowMenu(
                copy: copy,
                edit: { selectedReminder = item },
                delete: { deleting = .reminder(item) }
            )
        }
        .contentShape(.rect)
        .onTapGesture { selectedReminder = item }
        .keptCard(interactive: true)
    }

    private func memoryRow(_ item: MemoryItem, copy: Copy) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol(for: item.category))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.18)), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(item.title ?? item.text).fontWeight(.medium).lineLimit(1)
                    if item.recurringKey != nil {
                        Image(systemName: "repeat").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if item.sourceText != nil || item.title != nil {
                    Text(item.sourceText ?? item.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 5) {
                    Text(display(item.category))
                    Text("·")
                    Text(item.eventDate, format: .dateTime.month(.abbreviated).day().year())
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 6)
            rowMenu(
                copy: copy,
                edit: { selectedMemory = item },
                delete: { deleting = .memory(item) }
            )
        }
        .contentShape(.rect)
        .onTapGesture { selectedMemory = item }
        .keptCard(interactive: true)
    }

    private func rowMenu(copy: Copy, edit: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        Menu {
            Button(action: edit) { Label(copy.edit, systemImage: "pencil") }
            Divider()
            Button(role: .destructive, action: delete) { Label(copy.delete, systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .menuIndicator(.hidden)
    }

    private func title(for bucket: MemoryTimelineBucket, copy: Copy) -> String {
        switch bucket {
        case .overdue: copy.overdue
        case .today: copy.today
        case .upcoming: copy.upcoming
        case .previous: copy.previous
        }
    }

    private func display(_ category: String) -> String {
        category.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    private func symbol(for category: String) -> String {
        switch category {
        case "health", "salud": "heart.text.square"
        case "work", "trabajo": "briefcase"
        case "family", "familia": "person.2"
        case "finance", "finanzas": "creditcard"
        case "travel", "viajes": "airplane"
        default: "bookmark"
        }
    }

    private func deleteTitle(_ copy: Copy) -> String {
        guard let deleting else { return copy.delete }
        return switch deleting {
        case .reminder: copy.deleteTask
        case .memory: copy.deleteMemory
        }
    }

    private var deleteMessage: String {
        guard let deleting else { return "" }
        return switch deleting {
        case .reminder(let item): item.title
        case .memory(let item): item.title ?? item.text
        }
    }
}

private struct MemoryEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let item: MemoryItem
    @State private var title: String
    @State private var sourceText: String
    @State private var category: String

    init(item: MemoryItem) {
        self.item = item
        _title = State(initialValue: item.title ?? item.text)
        _sourceText = State(initialValue: item.sourceText ?? item.text)
        _category = State(initialValue: item.category)
    }

    var body: some View {
        let copy = resolvedCopy(store.settings)
        VStack(alignment: .leading, spacing: 14) {
            Label(copy.language == "es" ? "Editar recuerdo" : "Edit memory", systemImage: "brain.head.profile")
                .font(.title3.weight(.semibold))
            TextField(copy.title, text: $title).textFieldStyle(.roundedBorder)
            TextField(copy.originalText, text: $sourceText, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            TextField(copy.category, text: $category).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(copy.cancel) { dismiss() }.buttonStyle(.glass)
                Button(copy.save) {
                    item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                    item.category = category.lowercased().replacingOccurrences(of: " ", with: "_")
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .keptCard(padding: 22)
        .padding(22)
        .frame(width: 430)
        .keptScene()
    }
}

private struct ReminderEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: ReminderItem?
    @State private var title: String
    @State private var date: Date
    @State private var recurrence: RecurrenceFrequency
    @State private var recurrenceInterval: Int
    @State private var recurrenceWeekdays: Set<Int>
    @State private var recurrenceDayOfMonth: Int
    @State private var leadValue: Int
    @State private var leadUnit: LeadUnit

    init(item: ReminderItem?) {
        self.item = item
        let initialDate = item?.eventAt ?? Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        _title = State(initialValue: item?.title ?? "")
        _date = State(initialValue: initialDate)
        _recurrence = State(initialValue: item?.recurrence ?? .none)
        _recurrenceInterval = State(initialValue: item?.recurrenceInterval ?? 1)
        _recurrenceWeekdays = State(initialValue: Set(item?.recurrenceWeekdays ?? []))
        _recurrenceDayOfMonth = State(initialValue: item?.recurrenceDayOfMonth ?? Calendar.current.component(.day, from: initialDate))
        _leadValue = State(initialValue: item?.leadValue ?? 0)
        _leadUnit = State(initialValue: item?.leadUnit ?? .minute)
    }

    var body: some View {
        let copy = resolvedCopy(store.settings)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(item == nil ? copy.addTask : copy.editTask, systemImage: "checklist")
                    .font(.title3.weight(.semibold))
                TextField(copy.task, text: $title)
                    .textFieldStyle(.roundedBorder)
                DatePicker(copy.dateAndTime, selection: $date)
                Divider()
                Picker(copy.recurrence, selection: $recurrence) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { value in
                        Text(copy.recurrenceName(value)).tag(value)
                    }
                }
                if recurrence != .none {
                    Stepper(value: $recurrenceInterval, in: 1...99) {
                        Text("\(copy.interval) \(recurrenceInterval)")
                    }
                }
                if recurrence == .weekly {
                    weekdaySelector(copy: copy)
                }
                if recurrence == .monthly {
                    Stepper(value: $recurrenceDayOfMonth, in: 1...31) {
                        Text("\(copy.monthDay): \(recurrenceDayOfMonth)")
                    }
                }
                Divider()
                HStack {
                    Stepper(value: $leadValue, in: 0...999) {
                        Text(leadValue == 0 ? copy.atEventTime : "\(copy.alert) \(leadValue)")
                    }
                    if leadValue > 0 {
                        Picker("", selection: $leadUnit) {
                            ForEach(LeadUnit.allCases, id: \.self) { unit in
                                Text(copy.leadUnitName(unit, plural: leadValue != 1)).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                        Text(copy.before).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Spacer()
                    Button(copy.cancel) { dismiss() }.buttonStyle(.glass)
                    Button(copy.save) { save() }
                        .buttonStyle(.glassProminent)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .keptCard(padding: 22)
            .padding(22)
        }
        .frame(width: 480, height: recurrence == .weekly ? 560 : 500)
        .keptScene()
    }

    private func weekdaySelector(copy: Copy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.weeklyDays).font(.caption).foregroundStyle(.secondary)
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        let selected = recurrenceWeekdays.contains(day)
                        Button {
                            if selected { recurrenceWeekdays.remove(day) }
                            else { recurrenceWeekdays.insert(day) }
                        } label: {
                            Text(weekdayLabel(day, language: copy.language))
                                .font(.caption.weight(.semibold))
                                .frame(width: 25, height: 25)
                        }
                        .buttonStyle(.glass)
                        .tint(selected ? Color.accentColor : Color.secondary)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func weekdayLabel(_ isoWeekday: Int, language: String) -> String {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: language)
        let index = isoWeekday == 7 ? 0 : isoWeekday
        return calendar.veryShortWeekdaySymbols[index].uppercased()
    }

    private func save() {
        let input = ReminderScheduleInput(
            title: title,
            eventAt: date,
            recurrence: recurrence,
            recurrenceInterval: recurrenceInterval,
            recurrenceWeekdays: recurrenceWeekdays.sorted(),
            recurrenceDayOfMonth: recurrenceDayOfMonth,
            leadValue: leadValue,
            leadUnit: leadUnit
        )
        Task {
            if let item { await store.updateReminder(item, with: input) }
            else { await store.createManualReminder(input) }
            dismiss()
        }
    }
}
