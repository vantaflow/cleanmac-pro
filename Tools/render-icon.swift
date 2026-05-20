#!/usr/bin/env swift
// Renders the CleanMac Pro app icon at every required size for .icns.
// Style: macOS Sonoma squircle, dark gradient, sparkle symbol — inspired
// by modern utility app icons, not a copy of any specific product.

import AppKit
import CoreImage

let sizes: [(Int, String)] = [
    (16,  "icon_16x16.png"),
    (32,  "icon_16x16@2x.png"),
    (32,  "icon_32x32.png"),
    (64,  "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024,"icon_512x512@2x.png"),
]

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func squirclePath(rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func render(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.225  // macOS squircle ratio

    // Clip to squircle
    let path = squirclePath(rect: rect, radius: radius)
    path.addClip()

    // Background gradient: deep purple → teal
    let colors = [
        NSColor(srgbRed: 0.10, green: 0.08, blue: 0.22, alpha: 1.0).cgColor,
        NSColor(srgbRed: 0.05, green: 0.45, blue: 0.55, alpha: 1.0).cgColor,
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: s),
        end: CGPoint(x: s, y: 0),
        options: []
    )

    // Subtle radial highlight top-left
    let highlightColors = [
        NSColor(white: 1, alpha: 0.28).cgColor,
        NSColor(white: 1, alpha: 0).cgColor,
    ] as CFArray
    let highlight = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: highlightColors,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        highlight,
        startCenter: CGPoint(x: s * 0.3, y: s * 0.75),
        startRadius: 0,
        endCenter: CGPoint(x: s * 0.3, y: s * 0.75),
        endRadius: s * 0.55,
        options: []
    )

    // Sparkle / cleaning symbol — draw 4-pointed star + small accents
    let cx = s * 0.5
    let cy = s * 0.5
    let starSize = s * 0.34

    func fourPointStar(cx: CGFloat, cy: CGFloat, size: CGFloat, thin: CGFloat = 0.18) -> NSBezierPath {
        let p = NSBezierPath()
        let half = size
        let t = size * thin
        p.move(to: CGPoint(x: cx, y: cy + half))
        p.curve(
            to: CGPoint(x: cx + half, y: cy),
            controlPoint1: CGPoint(x: cx + t, y: cy + t),
            controlPoint2: CGPoint(x: cx + t, y: cy + t)
        )
        p.curve(
            to: CGPoint(x: cx, y: cy - half),
            controlPoint1: CGPoint(x: cx + t, y: cy - t),
            controlPoint2: CGPoint(x: cx + t, y: cy - t)
        )
        p.curve(
            to: CGPoint(x: cx - half, y: cy),
            controlPoint1: CGPoint(x: cx - t, y: cy - t),
            controlPoint2: CGPoint(x: cx - t, y: cy - t)
        )
        p.curve(
            to: CGPoint(x: cx, y: cy + half),
            controlPoint1: CGPoint(x: cx - t, y: cy + t),
            controlPoint2: CGPoint(x: cx - t, y: cy + t)
        )
        p.close()
        return p
    }

    // Glow behind main star
    NSColor(srgbRed: 0.55, green: 0.95, blue: 1.0, alpha: 0.35).setFill()
    let glow = fourPointStar(cx: cx, cy: cy, size: starSize * 1.15)
    glow.fill()

    // Main star — bright cyan/white
    NSColor.white.setFill()
    let star = fourPointStar(cx: cx, cy: cy, size: starSize)
    star.fill()

    // Accent stars — small ones top-right and bottom-left
    NSColor(white: 1, alpha: 0.85).setFill()
    fourPointStar(cx: s * 0.78, cy: s * 0.78, size: s * 0.09).fill()
    fourPointStar(cx: s * 0.22, cy: s * 0.22, size: s * 0.07).fill()

    img.unlockFocus()
    return img
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:])
    else { throw NSError(domain: "render", code: 1) }
    try data.write(to: url)
}

for (size, name) in sizes {
    let img = render(size: size)
    let url = outDir.appendingPathComponent(name)
    try writePNG(img, to: url)
    print("✓ \(name) (\(size)×\(size))")
}
print("\nDone. Run: iconutil -c icns \(outDir.path)")
