#!/usr/bin/env swift

import AppKit
import Foundation

private enum IconGenerationError: LocalizedError {
    case invalidArguments
    case bitmapCreationFailed(Int)
    case contextCreationFailed(Int)
    case pngEncodingFailed(Int)
    case iconutilFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Usage: swift Scripts/generate_icon.swift [output-directory]"
        case let .bitmapCreationFailed(size):
            return "Could not create a \(size)x\(size) icon bitmap."
        case let .contextCreationFailed(size):
            return "Could not create a drawing context for the \(size)x\(size) icon."
        case let .pngEncodingFailed(size):
            return "Could not encode the \(size)x\(size) icon as PNG."
        case let .iconutilFailed(status):
            return "iconutil failed with exit status \(status)."
        }
    }
}

private struct IconVariant {
    let pixels: Int
    let fileName: String
}

private let variants = [
    IconVariant(pixels: 16, fileName: "icon_16x16.png"),
    IconVariant(pixels: 32, fileName: "icon_16x16@2x.png"),
    IconVariant(pixels: 32, fileName: "icon_32x32.png"),
    IconVariant(pixels: 64, fileName: "icon_32x32@2x.png"),
    IconVariant(pixels: 128, fileName: "icon_128x128.png"),
    IconVariant(pixels: 256, fileName: "icon_128x128@2x.png"),
    IconVariant(pixels: 256, fileName: "icon_256x256.png"),
    IconVariant(pixels: 512, fileName: "icon_256x256@2x.png"),
    IconVariant(pixels: 512, fileName: "icon_512x512.png"),
    IconVariant(pixels: 1024, fileName: "icon_512x512@2x.png")
]

private func point(_ x: CGFloat, _ y: CGFloat, in rect: NSRect) -> NSPoint {
    NSPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
}

/// Draws an original pair of crossing "overture" ribbons over a stage-like field.
/// The shape is intentionally constructed from AppKit primitives rather than assets.
private func drawIcon(in rect: NSRect) {
    NSColor.clear.setFill()
    rect.fill()

    let inset = rect.width * 0.035
    let tileRect = rect.insetBy(dx: inset, dy: inset)
    let tile = NSBezierPath(
        roundedRect: tileRect,
        xRadius: rect.width * 0.225,
        yRadius: rect.height * 0.225
    )

    NSGraphicsContext.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    tileShadow.shadowBlurRadius = rect.width * 0.035
    tileShadow.shadowOffset = NSSize(width: 0, height: -rect.height * 0.018)
    tileShadow.set()
    NSColor(calibratedRed: 0.055, green: 0.045, blue: 0.15, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()

    let background = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.12, green: 0.07, blue: 0.31, alpha: 1), 0),
        (NSColor(calibratedRed: 0.36, green: 0.16, blue: 0.66, alpha: 1), 0.53),
        (NSColor(calibratedRed: 0.05, green: 0.31, blue: 0.38, alpha: 1), 1)
    )
    background?.draw(in: tile, angle: -38)

    let glowRect = NSRect(
        x: rect.width * 0.04,
        y: rect.height * 0.38,
        width: rect.width * 0.82,
        height: rect.height * 0.82
    )
    let glow = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.77, green: 0.46, blue: 1, alpha: 0.48), 0),
        (NSColor(calibratedRed: 0.39, green: 0.30, blue: 0.84, alpha: 0), 1)
    )
    glow?.draw(in: glowRect, relativeCenterPosition: NSPoint(x: -0.2, y: 0.18))

    let fineArc = NSBezierPath()
    fineArc.move(to: point(0.13, 0.29, in: rect))
    fineArc.curve(
        to: point(0.88, 0.53, in: rect),
        controlPoint1: point(0.34, 0.08, in: rect),
        controlPoint2: point(0.57, 0.79, in: rect)
    )
    fineArc.lineWidth = max(1, rect.width * 0.026)
    fineArc.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.20).setStroke()
    fineArc.stroke()

    let aquaRibbon = NSBezierPath()
    aquaRibbon.move(to: point(0.15, 0.31, in: rect))
    aquaRibbon.curve(
        to: point(0.86, 0.55, in: rect),
        controlPoint1: point(0.32, 0.12, in: rect),
        controlPoint2: point(0.60, 0.80, in: rect)
    )
    aquaRibbon.lineWidth = max(2, rect.width * 0.105)
    aquaRibbon.lineCapStyle = .round
    aquaRibbon.lineJoinStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let aquaShadow = NSShadow()
    aquaShadow.shadowColor = NSColor(calibratedRed: 0.02, green: 0.95, blue: 0.85, alpha: 0.34)
    aquaShadow.shadowBlurRadius = rect.width * 0.055
    aquaShadow.shadowOffset = .zero
    aquaShadow.set()
    NSColor(calibratedRed: 0.24, green: 0.91, blue: 0.80, alpha: 1).setStroke()
    aquaRibbon.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let lightRibbon = NSBezierPath()
    lightRibbon.move(to: point(0.15, 0.67, in: rect))
    lightRibbon.curve(
        to: point(0.86, 0.43, in: rect),
        controlPoint1: point(0.34, 0.89, in: rect),
        controlPoint2: point(0.57, 0.20, in: rect)
    )
    lightRibbon.lineWidth = max(2, rect.width * 0.125)
    lightRibbon.lineCapStyle = .round
    lightRibbon.lineJoinStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let lightShadow = NSShadow()
    lightShadow.shadowColor = NSColor(calibratedRed: 0.78, green: 0.50, blue: 1, alpha: 0.52)
    lightShadow.shadowBlurRadius = rect.width * 0.06
    lightShadow.shadowOffset = .zero
    lightShadow.set()
    NSColor(calibratedRed: 0.97, green: 0.94, blue: 1, alpha: 1).setStroke()
    lightRibbon.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let sparkleSize = rect.width * 0.085
    let sparkleRect = NSRect(
        x: rect.width * 0.49 - sparkleSize / 2,
        y: rect.height * 0.50 - sparkleSize / 2,
        width: sparkleSize,
        height: sparkleSize
    )
    NSColor.white.withAlphaComponent(0.96).setFill()
    NSBezierPath(ovalIn: sparkleRect).fill()

    let topHighlight = NSBezierPath()
    topHighlight.move(to: point(0.19, 0.79, in: rect))
    topHighlight.curve(
        to: point(0.80, 0.85, in: rect),
        controlPoint1: point(0.38, 0.94, in: rect),
        controlPoint2: point(0.65, 0.94, in: rect)
    )
    topHighlight.lineWidth = max(1, rect.width * 0.018)
    topHighlight.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.22).setStroke()
    topHighlight.stroke()

    NSGraphicsContext.restoreGraphicsState()

    tile.lineWidth = max(1, rect.width * 0.012)
    NSColor.white.withAlphaComponent(0.16).setStroke()
    tile.stroke()
}

private func writePNG(size: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconGenerationError.bitmapCreationFailed(size)
    }

    bitmap.size = NSSize(width: size, height: size)

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconGenerationError.contextCreationFailed(size)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    drawIcon(in: NSRect(x: 0, y: 0, width: size, height: size))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.pngEncodingFailed(size)
    }

    try png.write(to: url, options: .atomic)
}

private func absoluteURL(for path: String) -> URL {
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent(path, isDirectory: true)
        .standardizedFileURL
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count <= 1 else {
        throw IconGenerationError.invalidArguments
    }

    let outputDirectory = absoluteURL(for: arguments.first ?? "dist")
    let iconsetURL = outputDirectory.appendingPathComponent("Overture.iconset", isDirectory: true)
    let icnsURL = outputDirectory.appendingPathComponent("Overture.icns", isDirectory: false)
    let fileManager = FileManager.default

    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    if fileManager.fileExists(atPath: iconsetURL.path) {
        try fileManager.removeItem(at: iconsetURL)
    }
    try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: false)

    for variant in variants {
        try writePNG(
            size: variant.pixels,
            to: iconsetURL.appendingPathComponent(variant.fileName, isDirectory: false)
        )
    }

    if fileManager.fileExists(atPath: icnsURL.path) {
        try fileManager.removeItem(at: icnsURL)
    }

    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["--convert", "icns", "--output", icnsURL.path, iconsetURL.path]
    try iconutil.run()
    iconutil.waitUntilExit()

    guard iconutil.terminationStatus == 0 else {
        throw IconGenerationError.iconutilFailed(iconutil.terminationStatus)
    }

    print("Generated \(iconsetURL.path)")
    print("Generated \(icnsURL.path)")
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(EXIT_FAILURE)
}
