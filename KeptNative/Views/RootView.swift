// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var store = store
        let copy = resolvedCopy(store.settings)

        ZStack(alignment: .top) {
            KeptSceneBackground()

            Group {
                switch store.selectedTab {
                case .chat: ChatView()
                case .memory: MemoryView()
                }
            }
            .padding(.top, 78)
            .animation(.smooth(duration: 0.35), value: store.selectedTab)

            GlassEffectContainer(spacing: 18) {
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        navigationButton(.chat, title: copy.chat, symbol: "sparkles")
                        navigationButton(.memory, title: copy.memory, symbol: "brain.head.profile")
                    }

                    Button {
                        openWindow(id: "settings")
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .help(copy.language == "es" ? "Ajustes" : "Settings")
                }
            }
            .padding(.top, 12)
        }
        .frame(minWidth: 420, minHeight: 580)
        .tint(KeptTheme.accent(named: store.settings.accentName))
        .alert("Kept", isPresented: Binding(
            get: { store.confirmationPrompt != nil },
            set: { if !$0 { store.cancelPending() } }
        )) {
            Button(copy.cancel, role: .cancel) { store.cancelPending() }
            Button(copy.confirm) { Task { await store.confirmPending() } }
        } message: {
            Text(store.confirmationPrompt ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .keptOpenSettings)) { _ in
            openWindow(id: "settings")
        }
    }

    @ViewBuilder
    private func navigationButton(_ tab: AppTab, title: String, symbol: String) -> some View {
        let selected = store.selectedTab == tab
        Button {
            withAnimation(.smooth(duration: 0.32)) {
                store.selectedTab = tab
            }
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .padding(.horizontal, 13)
                .frame(height: 36)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.primary : Color.secondary)
        .glassEffect(
            selected
                ? .regular.tint(Color.accentColor.opacity(0.28)).interactive()
                : .regular.interactive(),
            in: .capsule
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
