// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import SwiftUI

struct ChatRing: View {
    var active: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(active ? 0.16 : 0.08))
                .frame(width: 88, height: 88)
                .glassEffect(.regular, in: .circle)

            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate / 1.45
                Canvas { context, size in
                    let radius = min(size.width, size.height) * 0.30
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    var path = Path()
                    let points = 64
                    for index in 0...points {
                        let angle = Double(index) / Double(points) * .pi * 2
                        let wobble = active ? 0.5 : 2.4
                        let radial = radius + wobble * sin(angle * 3 + phase) + wobble * 0.45 * sin(angle * 2 - phase * 1.3)
                        let point = CGPoint(x: center.x + radial * cos(angle), y: center.y + radial * sin(angle))
                        index == 0 ? path.move(to: point) : path.addLine(to: point)
                    }
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [.white.opacity(0.65), .accentColor, .accentColor.opacity(0.65)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        ),
                        lineWidth: 4
                    )
                }
            }
        }
        .frame(width: 116, height: 116)
        .scaleEffect(active ? 1.035 : 1)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: active)
        .accessibilityHidden(true)
    }
}
