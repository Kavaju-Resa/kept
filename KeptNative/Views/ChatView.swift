// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import SwiftData
import SwiftUI

struct ChatView: View {
    @Environment(AppStore.self) private var store
    @Query(sort: \ConversationMessage.createdAt) private var messages: [ConversationMessage]
    @State private var input = ""
    @State private var historyIndex: Int?
    @State private var dictation = DictationService()
    @FocusState private var focused: Bool

    var body: some View {
        let copy = resolvedCopy(store.settings)
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 13) {
                        if messages.isEmpty {
                            ChatRing(active: focused || store.isThinking)
                                .padding(.top, 72)
                            Text(copy.language == "es" ? "¿Qué quieres recordar?" : "What would you like to remember?")
                                .font(.title3.weight(.semibold))
                            Text(copy.noMessages)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 300)
                        } else {
                            ChatRing(active: focused || store.isThinking)
                                .frame(width: 58, height: 58)
                                .padding(.top, 10)
                            ForEach(messages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                            }
                            if store.isThinking {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text(copy.language == "es" ? "Interpretando…" : "Interpreting…")
                                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .keptCard(padding: 11)
                            }
                        }
                    }
                    .frame(maxWidth: KeptTheme.narrowColumn)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: messages.count) { _, _ in
                    if let id = messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }

            GlassEffectContainer(spacing: 12) {
                HStack(alignment: .bottom, spacing: 9) {
                    TextField(copy.placeholder, text: $input, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .lineLimit(1...5)
                        .focused($focused)
                        .onSubmit { submit() }
                        .onKeyPress(.upArrow) {
                            navigateHistory(direction: 1)
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            navigateHistory(direction: -1)
                            return .handled
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))

                    Button {
                        if dictation.isRecording {
                            dictation.stop()
                            if !dictation.transcript.isEmpty { input = dictation.transcript }
                        } else {
                            Task { await dictation.start(language: store.settings.dictationLanguage) }
                        }
                    } label: {
                        Image(systemName: dictation.isRecording ? "waveform" : "mic.fill")
                            .symbolEffect(.pulse, isActive: dictation.isRecording)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(dictation.isRecording ? .red : .accentColor)
                    .help(copy.language == "es" ? "Dictar" : "Dictate")

                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isThinking)
                }
            }
            .frame(maxWidth: KeptTheme.narrowColumn)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: dictation.transcript) { _, value in if dictation.isRecording { input = value } }
        .alert("Kept", isPresented: Binding(get: { dictation.errorMessage != nil }, set: { if !$0 { dictation.errorMessage = nil } })) {
            Button("OK") { dictation.errorMessage = nil }
        } message: { Text(dictation.errorMessage ?? "") }
    }

    private func submit() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        input = ""
        historyIndex = nil
        Task { await store.send(value) }
    }

    private func navigateHistory(direction: Int) {
        let history = messages.filter { $0.roleRaw == "user" }.map(\.text).reversed()
        let values = Array(history)
        guard !values.isEmpty else { return }
        let next = min(max((historyIndex ?? -1) + direction, 0), values.count - 1)
        historyIndex = next
        input = values[next]
    }
}

private struct MessageRow: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.roleRaw == "user" { Spacer(minLength: 52) }
            VStack(alignment: .leading, spacing: 5) {
                Text(message.text)
                    .font(.system(size: 13.5))
                    .textSelection(.enabled)
                if message.kindRaw == "clarification" && message.clarificationExpired {
                    Text("Expired").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(
                message.roleRaw == "user"
                    ? .regular.tint(Color.accentColor.opacity(0.30))
                    : .regular,
                in: .rect(cornerRadius: 17)
            )
            if message.roleRaw != "user" { Spacer(minLength: 52) }
        }
    }
}
