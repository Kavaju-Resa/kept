// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import SwiftUI

enum KeptTheme {
    static let corner: CGFloat = 22
    static let compactCorner: CGFloat = 16
    static let narrowColumn: CGFloat = 480
    static let glassSpacing: CGFloat = 14

    static func accent(named name: String) -> Color {
        switch name {
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "graphite": .gray
        default: .accentColor
        }
    }
}

struct KeptSceneBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color.clear,
                    Color.primary.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: -190, y: -250)
            Circle()
                .fill(Color.purple.opacity(0.065))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 220, y: 300)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct KeptGlassCardModifier: ViewModifier {
    let interactive: Bool
    let padding: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if interactive {
            content
                .padding(padding)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: KeptTheme.corner))
                .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
        } else {
            content
                .padding(padding)
                .glassEffect(.regular, in: .rect(cornerRadius: KeptTheme.corner))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        }
    }
}

extension View {
    func keptCard(interactive: Bool = false, padding: CGFloat = 14) -> some View {
        modifier(KeptGlassCardModifier(interactive: interactive, padding: padding))
    }

    func keptScene() -> some View {
        background { KeptSceneBackground() }
    }
}

struct KeptSectionTitle: View {
    let title: String
    let count: Int?

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.7)
            if let count {
                Text("\(count)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .glassEffect(.regular, in: .capsule)
            }
        }
    }
}
