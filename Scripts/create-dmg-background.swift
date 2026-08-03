// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: create-dmg-background.swift <output.png>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let retinaOutputURL = URL(
    fileURLWithPath: outputURL.deletingPathExtension().path + "@2x." + outputURL.pathExtension
)
let logicalSize = NSSize(width: 660, height: 400)

func renderBackground(scale: Int, dpi: CGFloat, to destination: URL) throws {
    let pixelWidth = Int(logicalSize.width) * scale
    let pixelHeight = Int(logicalSize.height) * scale

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(
            domain: "KeptInstallerArtwork",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to create installer artwork."]
        )
    }

    // PNG stores resolution through its logical size. The @2x asset uses a
    // fractionally higher DPI so Finder never sees it as larger than 660x400pt.
    bitmap.size = NSSize(
        width: CGFloat(pixelWidth) * 72 / dpi,
        height: CGFloat(pixelHeight) * 72 / dpi
    )

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    let bounds = NSRect(origin: .zero, size: logicalSize)
    NSColor(calibratedRed: 246 / 255, green: 241 / 255, blue: 230 / 255, alpha: 1).setFill()
    bounds.fill()

    // Finder supplies both icons and their localized labels. The background
    // only provides a language-neutral, solid chevron between them.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 319, y: 222))
    arrow.line(to: NSPoint(x: 341, y: 200))
    arrow.line(to: NSPoint(x: 319, y: 178))
    NSColor(calibratedRed: 45 / 255, green: 36 / 255, blue: 22 / 255, alpha: 1).setStroke()
    arrow.lineWidth = 7
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(
            domain: "KeptInstallerArtwork",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Unable to encode installer artwork."]
        )
    }

    try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try png.write(to: destination, options: .atomic)
}

do {
    try renderBackground(scale: 1, dpi: 72, to: outputURL)
    try renderBackground(scale: 2, dpi: 144.07, to: retinaOutputURL)
} catch {
    fputs("Unable to write installer artwork: \(error)\n", stderr)
    exit(1)
}
