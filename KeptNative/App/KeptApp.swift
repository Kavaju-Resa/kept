import SwiftData
import SwiftUI

@main
struct KeptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @State private var store: AppStore

    init() {
        do {
            let schema = Schema([ReminderItem.self, MemoryItem.self, ConversationMessage.self, PatternRecord.self])
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "com.kavaju.kept", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(url: support.appending(path: "Kept.store"))
            let container = try ModelContainer(for: schema, configurations: configuration)
            self.container = container
            _store = State(initialValue: AppStore(container: container))
        } catch {
            fatalError("Unable to create Kept data store: \(error)")
        }
    }

    var body: some Scene {
        Window("Kept", id: "main") {
            RootView()
                .environment(store)
                .modelContainer(container)
                .background(WindowAccessor(role: .main))
                .task { await store.start() }
        }
        .defaultSize(width: 520, height: 800)
        .windowResizability(.contentMinSize)
        .commands { KeptCommands() }

        Window("Settings", id: "settings") {
            SettingsView()
                .environment(store)
                .modelContainer(container)
                .background(WindowAccessor(role: .settings))
        }
        .defaultSize(width: 760, height: 680)
        .windowResizability(.contentSize)
    }
}

private struct KeptCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var updates = UpdateService.shared

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { openWindow(id: "settings") }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { updates.checkForUpdates() }
                .disabled(!updates.isConfigured)
        }
    }
}
