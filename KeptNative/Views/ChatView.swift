// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import AppKit
import FoundationModels
import SwiftData
import SwiftUI

struct ChatView: View {
    @Environment(AppStore.self) private var store
    @Query(sort: \ConversationMessage.createdAt) private var messages: [ConversationMessage]
    @State private var input = ""
    @State private var historyIndex: Int?
    @State private var dictation = DictationService()
    @State private var translationMode = false
    @State private var sourceLanguage: TranslationLanguage = .automatic
    @State private var targetLanguage: TranslationLanguage = .spanish
    @State private var translationStyle: TranslationStyle = .natural
    @State private var isSubmittingTranslation = false
    @State private var didSetTranslationDefaults = false
    @State private var dictationHotkeyHeld = false
    @FocusState private var focused: Bool

    var body: some View {
        let copy = resolvedCopy(store.settings)
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 13) {
                        if messages.isEmpty {
                            ChatRing(active: isChatRingBreathing)
                                .padding(.top, 72)
                            Text(copy.language == "es" ? "¿Qué quieres recordar?" : "What would you like to remember?")
                                .font(.title3.weight(.semibold))
                            Text(copy.noMessages)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 300)
                        } else {
                            ChatRing(active: isChatRingBreathing, diameter: 58)
                                .padding(.top, 10)
                            ForEach(messages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                            }
                            if store.isThinking {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text(isSubmittingTranslation ? copy.translating : (copy.language == "es" ? "Interpretando…" : "Interpreting…"))
                                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .keptCard(padding: 11)
                            }
                        }
                    }
                    .frame(maxWidth: KeptTheme.narrowColumn)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 64)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: messages.count) { _, _ in
                    if let id = messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }

            composer(copy: copy)
            .frame(maxWidth: KeptTheme.narrowColumn)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: dictation.transcript) { _, value in
            if dictation.isRecording || dictationHotkeyHeld { input = value }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keptDictationHotkeyPressed)) { _ in
            beginHotkeyDictation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .keptDictationHotkeyReleased)) { _ in
            endHotkeyDictation()
        }
        .onDisappear {
            dictationHotkeyHeld = false
            dictation.stop()
        }
        .onAppear {
            guard !didSetTranslationDefaults else { return }
            targetLanguage = copy.language == "es" ? .english : .spanish
            didSetTranslationDefaults = true
        }
        .alert("Kept", isPresented: Binding(get: { dictation.errorMessage != nil }, set: { if !$0 { dictation.errorMessage = nil } })) {
            Button("OK") { dictation.errorMessage = nil }
        } message: { Text(dictation.errorMessage ?? "") }
    }

    private var showsSlashCommand: Bool {
        !translationMode && input.trimmingCharacters(in: .whitespacesAndNewlines) == "/"
    }

    private var isChatRingBreathing: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func composer(copy: Copy) -> some View {
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .bottom, spacing: 9) {
                TextField(translationMode ? copy.translationPlaceholder : copy.placeholder, text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...5)
                    .focused($focused)
                    .onSubmit {
                        if showsSlashCommand {
                            enterTranslationMode()
                        } else {
                            submit()
                        }
                    }
                    .onKeyPress(.upArrow) {
                        navigateHistory(direction: 1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        navigateHistory(direction: -1)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        guard translationMode || showsSlashCommand else { return .ignored }
                        dismissFloatingControls()
                        return .handled
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .glassEffect(
                        translationMode
                            ? .regular.tint(Color.accentColor.opacity(0.14)).interactive()
                            : .regular.interactive(),
                        in: .rect(cornerRadius: 20)
                    )

                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isThinking || showsSlashCommand)
            }
            .overlay(alignment: .bottom) {
                floatingControls(copy: copy)
                    .padding(.bottom, 58)
                    .zIndex(2)
            }
        }
        .animation(.smooth(duration: 0.28), value: translationMode)
        .animation(.smooth(duration: 0.24), value: showsSlashCommand)
    }

    @ViewBuilder
    private func floatingControls(copy: Copy) -> some View {
        if translationMode {
            translationControls(copy: copy)
                .transition(.blurReplace)
        } else if showsSlashCommand {
            Button {
                enterTranslationMode()
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "character.bubble")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .glassEffect(.regular.tint(Color.accentColor.opacity(0.16)), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.translationMode)
                            .font(.system(size: 13, weight: .semibold))
                        Text(copy.language == "es" ? "Traduce con un tono natural" : "Translate with a natural tone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 22)
                    Image(systemName: "return")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .frame(height: 52)
                .contentShape(.rect(cornerRadius: 17))
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 17))
            }
            .buttonStyle(.plain)
            .transition(.blurReplace)
        }
    }

    private func translationControls(copy: Copy) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                languageMenu(
                    title: copy.sourceLanguage,
                    selection: $sourceLanguage,
                    options: supportedTranslationLanguages(includeAutomatic: true),
                    copy: copy
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(copy.language == "es" ? "hacia" : "to")

                languageMenu(
                    title: copy.targetLanguage,
                    selection: $targetLanguage,
                    options: supportedTranslationLanguages(includeAutomatic: false),
                    copy: copy,
                    disabledOption: sourceLanguage == .automatic ? nil : sourceLanguage
                )

                Menu {
                    ForEach(TranslationStyle.allCases) { style in
                        Button {
                            translationStyle = style
                        } label: {
                            if translationStyle == style {
                                Label(style.displayName(interfaceLanguage: copy.language), systemImage: "checkmark")
                            } else {
                                Text(style.displayName(interfaceLanguage: copy.language))
                            }
                        }
                    }
                } label: {
                    Image(systemName: "textformat")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(translationStyle == .natural ? Color.secondary : Color.accentColor)
                        .frame(width: 34, height: 34)
                        .contentShape(.circle)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .menuStyle(.borderlessButton)
                .help("\(copy.textStyle): \(translationStyle.displayName(interfaceLanguage: copy.language))")

                Button {
                    dismissFloatingControls()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help(copy.exitTranslation)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func supportedTranslationLanguages(includeAutomatic: Bool) -> [TranslationLanguage] {
        TranslationLanguage.allCases.filter { language in
            if language == .automatic { return includeAutomatic }
            return SystemLanguageModel.default.supportsLocale(Locale(identifier: language.localeIdentifier))
        }
    }

    private func languageMenu(
        title: String,
        selection: Binding<TranslationLanguage>,
        options: [TranslationLanguage],
        copy: Copy,
        disabledOption: TranslationLanguage? = nil
    ) -> some View {
        Menu {
            ForEach(options) { language in
                Button {
                    selection.wrappedValue = language
                    if sourceLanguage != .automatic, sourceLanguage == targetLanguage {
                        targetLanguage = sourceLanguage == .english ? .spanish : .english
                    }
                } label: {
                    if selection.wrappedValue == language {
                        Label(language.displayName(interfaceLanguage: copy.language), systemImage: "checkmark")
                    } else {
                        Text(language.displayName(interfaceLanguage: copy.language))
                    }
                }
                .disabled(language == disabledOption)
            }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(selection.wrappedValue.displayName(interfaceLanguage: copy.language))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .contentShape(.rect(cornerRadius: 14))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("\(title): \(selection.wrappedValue.displayName(interfaceLanguage: copy.language))")
    }

    private func dismissFloatingControls() {
        withAnimation(.smooth(duration: 0.24)) {
            translationMode = false
            if showsSlashCommand { input = "" }
        }
    }

    private func enterTranslationMode() {
        withAnimation(.smooth(duration: 0.28)) {
            input = ""
            translationMode = true
        }
        focused = true
    }

    private func beginHotkeyDictation() {
        guard !dictationHotkeyHeld else { return }
        dictationHotkeyHeld = true
        focused = true
        Task {
            await dictation.start(language: store.settings.dictationLanguage)
            if !dictationHotkeyHeld { dictation.stop() }
        }
    }

    private func endHotkeyDictation() {
        guard dictationHotkeyHeld else { return }
        dictationHotkeyHeld = false
        dictation.stop()
        if !dictation.transcript.isEmpty { input = dictation.transcript }
    }

    private func submit() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !showsSlashCommand else { return }
        let request = TranslationRequest(source: sourceLanguage, target: targetLanguage, style: translationStyle)
        let shouldTranslate = translationMode
        input = ""
        historyIndex = nil
        Task {
            if shouldTranslate {
                isSubmittingTranslation = true
                await store.translate(value, request: request)
                isSubmittingTranslation = false
            } else {
                await store.send(value)
            }
        }
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
    @Environment(AppStore.self) private var store
    let message: ConversationMessage
    @State private var copied = false

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
                if message.kindRaw == "translation" {
                    HStack {
                        Text(resolvedCopy(store.settings).translationMode)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                            withAnimation(.smooth(duration: 0.2)) { copied = true }
                            Task {
                                try? await Task.sleep(for: .seconds(1.4))
                                withAnimation(.smooth(duration: 0.2)) { copied = false }
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .semibold))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(copied ? Color.accentColor : Color.secondary)
                        .help(resolvedCopy(store.settings).copyTranslation)
                    }
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
