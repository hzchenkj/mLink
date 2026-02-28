#!/usr/bin/env swift
import AppKit
import Foundation

let args = CommandLine.arguments
let outputPath = args.count > 1 ? args[1] : "AppIcon.icns"

let fm = FileManager.default
let tmpRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
let iconsetURL = tmpRoot.appendingPathComponent("mcd_icon_\(UUID().uuidString).iconset", isDirectory: true)

try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let red = NSColor(calibratedRed: 0.84, green: 0.07, blue: 0.13, alpha: 1.0)
let yellow = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.12, alpha: 1.0)

func drawIcon(size: Int, to url: URL) throws {
    let imageSize = NSSize(width: size, height: size)
    guard let rep = NSBitmapImageRep(
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
        throw NSError(domain: "icon-gen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate bitmap"]) 
    }

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        NSGraphicsContext.restoreGraphicsState()
        throw NSError(domain: "icon-gen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context"])
    }
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high

    let rect = NSRect(origin: .zero, size: imageSize)
    let corner = CGFloat(size) * 0.22
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
    red.setFill()
    bgPath.fill()

    // Draw a stylized golden-arches "M".
    let lineWidth = CGFloat(size) * 0.14
    let inset = CGFloat(size) * 0.20
    let baseY = CGFloat(size) * 0.18
    let topY = CGFloat(size) * 0.78
    let middleX = CGFloat(size) * 0.50
    let leftBaseX = inset
    let rightBaseX = CGFloat(size) - inset

    let leftArch = NSBezierPath()
    leftArch.lineWidth = lineWidth
    leftArch.lineCapStyle = .round
    leftArch.move(to: NSPoint(x: leftBaseX, y: baseY))
    leftArch.curve(
        to: NSPoint(x: middleX, y: baseY),
        controlPoint1: NSPoint(x: leftBaseX, y: topY),
        controlPoint2: NSPoint(x: middleX, y: topY)
    )

    let rightArch = NSBezierPath()
    rightArch.lineWidth = lineWidth
    rightArch.lineCapStyle = .round
    rightArch.move(to: NSPoint(x: middleX, y: baseY))
    rightArch.curve(
        to: NSPoint(x: rightBaseX, y: baseY),
        controlPoint1: NSPoint(x: middleX, y: topY),
        controlPoint2: NSPoint(x: rightBaseX, y: topY)
    )

    yellow.setStroke()
    leftArch.stroke()
    rightArch.stroke()

    // Slightly mask lower stroke to keep proportions crisp on small sizes.
    let maskHeight = CGFloat(size) * 0.05
    let maskRect = NSRect(x: 0, y: baseY - lineWidth * 0.5 - maskHeight, width: CGFloat(size), height: maskHeight)
    red.setFill()
    NSBezierPath(rect: maskRect).fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon-gen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    try data.write(to: url)
}

for (name, size) in specs {
    try drawIcon(size: size, to: iconsetURL.appendingPathComponent(name))
}

let outputURL = URL(fileURLWithPath: outputPath)
let parent = outputURL.deletingLastPathComponent()
if !fm.fileExists(atPath: parent.path) {
    try fm.createDirectory(at: parent, withIntermediateDirectories: true)
}
if fm.fileExists(atPath: outputURL.path) {
    try fm.removeItem(at: outputURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "icon-gen", code: Int(process.terminationStatus), userInfo: [
        NSLocalizedDescriptionKey: "iconutil failed with status \(process.terminationStatus)"
    ])
}

try? fm.removeItem(at: iconsetURL)
print("Generated icon: \(outputURL.path)")
