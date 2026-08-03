import FoundationModels
import SwiftData
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general, intelligence, dictation, proactive, preferences, updates, about
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .intelligence: "sparkles"
        case .dictation: "mic"
        case .proactive: "bell"
        case .preferences: "checklist"
        case .updates: "arrow.triangle.2.circlepath"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @ObservedObject private var updates = UpdateService.shared
    @State private var section: SettingsSection = .general
    @State private var updateFeedDraft = ""

    var body: some View {
        @Bindable var settings = store.settings
        let copy = resolvedCopy(settings)
        HStack(spacing: 0) {
            GlassEffectContainer(spacing: 9) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable().scaledToFit().frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Kept").font(.headline)
                            Text(copy.language == "es" ? "Ajustes" : "Settings")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)

                    ForEach(SettingsSection.allCases) { item in
                        sidebarButton(item, copy: copy)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .frame(width: 205)

            Divider().opacity(0.16)

            ScrollView {
                GlassEffectContainer(spacing: 22) {
                    VStack(alignment: .leading, spacing: 22) {
                        Label(label(section, copy: copy), systemImage: section.icon)
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 2)
                        Group {
                            switch section {
                            case .general: general(settings: settings, copy: copy)
                            case .intelligence: intelligence(copy: copy)
                            case .dictation: dictation(settings: settings, copy: copy)
                            case .proactive: proactive(settings: settings, copy: copy)
                            case .preferences: preferences(settings: settings, copy: copy)
                            case .updates: updateSettings(copy: copy)
                            case .about: about(copy: copy)
                            }
                        }
                    }
                }
                .padding(26)
            }
        }
        .frame(width: 760, height: 680)
        .keptScene()
        .tint(KeptTheme.accent(named: settings.accentName))
        .onAppear {
            updates.refreshConfiguration()
            updateFeedDraft = updates.customFeedURLString
        }
    }

    private func sidebarButton(_ item: SettingsSection, copy: Copy) -> some View {
        let selected = section == item
        return Button {
            withAnimation(.smooth(duration: 0.28)) { section = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon).frame(width: 19)
                Text(label(item, copy: copy)).lineLimit(1)
                Spacer()
            }
            .font(.system(size: 13, weight: selected ? .semibold : .medium))
            .padding(.horizontal, 11)
            .frame(height: 38)
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.primary : Color.secondary)
        .glassEffect(
            selected
                ? .regular.tint(Color.accentColor.opacity(0.26)).interactive()
                : .regular.interactive(),
            in: .rect(cornerRadius: 13)
        )
    }

    private func general(settings: AppSettings, copy: Copy) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            group(copy.language == "es" ? "Apariencia" : "Appearance") {
                Picker(copy.language == "es" ? "Tema" : "Theme", selection: Binding(
                    get: { settings.appearanceName },
                    set: {
                        settings.appearanceName = $0
                        NSApp.appearance = switch $0 {
                        case "dark": NSAppearance(named: .darkAqua)
                        case "light": NSAppearance(named: .aqua)
                        default: nil
                        }
                    }
                )) {
                    Text(copy.language == "es" ? "Sistema" : "System").tag("system")
                    Text(copy.language == "es" ? "Claro" : "Light").tag("light")
                    Text(copy.language == "es" ? "Oscuro" : "Dark").tag("dark")
                }
                Picker(copy.language == "es" ? "Color" : "Accent", selection: Binding(get: { settings.accentName }, set: { settings.accentName = $0 })) {
                    ForEach(["system", "blue", "purple", "pink", "red", "orange", "yellow", "green", "graphite"], id: \.self) { Text($0.capitalized).tag($0) }
                }
            }
            group(copy.language == "es" ? "General" : "General") {
                Toggle(copy.language == "es" ? "Abrir al iniciar sesión" : "Launch at login", isOn: Binding(get: { settings.launchAtLogin }, set: {
                    settings.launchAtLogin = $0
                    try? settings.applyLaunchAtLogin()
                }))
                Toggle(copy.language == "es" ? "Confirmar antes de salir" : "Confirm before quitting", isOn: Binding(get: { settings.confirmBeforeQuit }, set: { settings.confirmBeforeQuit = $0 }))
                Picker(copy.language == "es" ? "Idioma" : "Language", selection: Binding(get: { settings.interfaceLanguage }, set: { settings.interfaceLanguage = $0 })) {
                    Text("Auto").tag("auto")
                    Text("Español").tag("es")
                    Text("English").tag("en")
                }
            }
        }
    }

    private func intelligence(copy: Copy) -> some View {
        group("Apple Intelligence") {
            HStack {
                Image(systemName: availabilityIcon).foregroundStyle(availabilityColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(availabilityTitle(copy: copy)).fontWeight(.medium)
                    Text(copy.language == "es" ? "Todo el procesamiento permanece en este Mac." : "All processing stays on this Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if case .unavailable = store.assistantAvailability {
                Button(copy.language == "es" ? "Abrir ajustes de Apple Intelligence" : "Open Apple Intelligence settings") {
                    store.openAppleIntelligenceSettings()
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func dictation(settings: AppSettings, copy: Copy) -> some View {
        group(copy.language == "es" ? "Dictado" : "Dictation") {
            Picker(copy.language == "es" ? "Idioma de dictado" : "Dictation language", selection: Binding(get: { settings.dictationLanguage }, set: { settings.dictationLanguage = $0 })) {
                Text("Auto").tag("auto")
                Text("Español").tag("es-ES")
                Text("English").tag("en-US")
            }
            Text(copy.language == "es" ? "Mantén el botón del micrófono en Chat para hablar." : "Use the microphone button in Chat to speak.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func proactive(settings: AppSettings, copy: Copy) -> some View {
        group(copy.language == "es" ? "Sugerencias proactivas" : "Proactive suggestions") {
            Toggle(copy.language == "es" ? "Detectar patrones locales" : "Detect local patterns", isOn: Binding(get: { settings.proactiveSuggestions }, set: { settings.proactiveSuggestions = $0 }))
            Stepper(value: Binding(get: { settings.patternLeadDays }, set: { settings.patternLeadDays = min(30, max(0, $0)) }), in: 0...30) {
                Text(copy.language == "es" ? "Avisar \(settings.patternLeadDays) días antes" : "Alert \(settings.patternLeadDays) days before")
            }
        }
    }

    private func preferences(settings: AppSettings, copy: Copy) -> some View {
        group(copy.language == "es" ? "Recordatorios" : "Reminders") {
            TextField("HH:mm", text: Binding(get: { settings.defaultReminderTime }, set: { settings.defaultReminderTime = $0 }))
            Stepper(value: Binding(get: { settings.snoozeDays }, set: { settings.snoozeDays = max(1, $0) }), in: 1...30) {
                Text(copy.language == "es" ? "Posponer \(settings.snoozeDays) días" : "Snooze \(settings.snoozeDays) days")
            }
        }
    }

    private func updateSettings(copy: Copy) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            group(copy.language == "es" ? "Actualizaciones automáticas" : "Automatic updates") {
                HStack(spacing: 10) {
                    Image(systemName: updates.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(updates.isConfigured ? .green : .orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(updates.isConfigured
                            ? (copy.language == "es" ? "Canal configurado" : "Update channel configured")
                            : (copy.language == "es" ? "Canal pendiente de configurar" : "Update channel needs configuration"))
                            .fontWeight(.medium)
                        if let feed = updates.activeFeedURL {
                            Text(feed.isFileURL
                                ? (copy.language == "es" ? "Fuente local privada" : "Private local source")
                                : feed.host ?? feed.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Toggle(
                    copy.language == "es" ? "Buscar actualizaciones automáticamente" : "Automatically check for updates",
                    isOn: Binding(
                        get: { updates.automaticallyChecksForUpdates },
                        set: { updates.automaticallyChecksForUpdates = $0 }
                    )
                )
                Toggle(
                    copy.language == "es" ? "Descargar actualizaciones automáticamente" : "Automatically download updates",
                    isOn: Binding(
                        get: { updates.automaticallyDownloadsUpdates },
                        set: { updates.automaticallyDownloadsUpdates = $0 }
                    )
                )
                .disabled(!updates.automaticallyChecksForUpdates)

                Button(copy.language == "es" ? "Buscar actualizaciones…" : "Check for Updates…") {
                    updates.checkForUpdates()
                }
                .buttonStyle(.glassProminent)
                .disabled(!updates.isConfigured)
            }

            if updates.allowsCustomFeed {
                group(copy.language == "es" ? "Fuente avanzada" : "Advanced source") {
                    Text(copy.language == "es"
                        ? "Kept usa automáticamente el canal privado local. También puedes indicar un appcast HTTPS propio."
                        : "Kept automatically uses the private local channel. You can also provide your own HTTPS appcast.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://updates.example.com/appcast.xml", text: $updateFeedDraft)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(copy.language == "es" ? "Aplicar fuente" : "Apply source") {
                            _ = updates.setCustomFeedURL(updateFeedDraft)
                        }
                        .buttonStyle(.glass)
                        Button(copy.language == "es" ? "Usar fuente local" : "Use local source") {
                            updateFeedDraft = ""
                            _ = updates.setCustomFeedURL("")
                        }
                        .buttonStyle(.glass)
                    }
                    if let error = updates.configurationError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func about(copy: Copy) -> some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().scaledToFit().frame(width: 92, height: 92)
                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
            Text("Kept").font(.title2.weight(.semibold))
            Text(version).foregroundStyle(.secondary)
            Text(copy.language == "es" ? "Tu memoria, descargada. Privada y local." : "Your memory, offloaded. Private and local.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .keptCard(padding: 34)
        .padding(.top, 30)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 14) { content() }.keptCard(padding: 17)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(_ section: SettingsSection, copy: Copy) -> String {
        switch section {
        case .general: copy.language == "es" ? "General" : "General"
        case .intelligence: "IA"
        case .dictation: copy.language == "es" ? "Dictado" : "Dictation"
        case .proactive: copy.language == "es" ? "Avisos" : "Alerts"
        case .preferences: copy.language == "es" ? "Preferencias" : "Preferences"
        case .updates: copy.language == "es" ? "Actualizaciones" : "Updates"
        case .about: copy.language == "es" ? "Acerca" : "About"
        }
    }

    private var availabilityIcon: String {
        if case .available = store.assistantAvailability { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }
    private var availabilityColor: Color {
        if case .available = store.assistantAvailability { return .green }
        return .orange
    }
    private func availabilityTitle(copy: Copy) -> String {
        if case .available = store.assistantAvailability { return copy.language == "es" ? "Disponible" : "Available" }
        return copy.language == "es" ? "No disponible; modo manual activo" : "Unavailable; manual mode active"
    }
}
