#!/usr/bin/env swift
// Renders the CleanMac Pro app icon for .icns. Style ported from the design's
// icon.svg: dark teal squircle, concentric mint rings, mint pulse dot, soft
// radial glow.

import AppKit

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

func render(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.225
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()

    // Dark teal background gradient
    let bg = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(srgbRed: 0.047, green: 0.122, blue: 0.102, alpha: 1.0).cgColor,
            NSColor(srgbRed: 0.039, green: 0.20,  blue: 0.16,  alpha: 1.0).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: s, y: s), options: [])

    // Soft mint glow
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(srgbRed: 0, green: 0.85, blue: 0.64, alpha: 0.6).cgColor,
            NSColor(srgbRed: 0, green: 0.85, blue: 0.64, alpha: 0).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    let c = CGPoint(x: s/2, y: s/2)
    ctx.drawRadialGradient(glow, startCenter: c, startRadius: 0,
                           endCenter: c, endRadius: s * 0.4, options: [])

    // Mint gradient brush for strokes
    let mintTop = NSColor(srgbRed: 0, green: 0.94, blue: 0.71, alpha: 1)
    let mintBot = NSColor(srgbRed: 0, green: 0.63, blue: 0.48, alpha: 1)

    // Outer ring (faint full circle r=0.28s)
    do {
        let r = s * 0.281
        let path = NSBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: 2*r, height: 2*r))
        path.lineWidth = s * 0.031
        mintTop.withAlphaComponent(0.55).setStroke()
        path.stroke()
    }

    // Inner ring (full circle r=0.203s)
    do {
        let r = s * 0.203
        let path = NSBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: 2*r, height: 2*r))
        path.lineWidth = s * 0.034
        mintTop.withAlphaComponent(0.85).setStroke()
        path.stroke()
    }

    // Animated-looking dash arc on the outer ring
    do {
        let r = s * 0.281
        let path = NSBezierPath()
        path.appendArc(
            withCenter: c, radius: r,
            startAngle: 90, endAngle: 90 + (28.0 / 160.0) * 360,
            clockwise: false
        )
        path.lineWidth = s * 0.034
        path.lineCapStyle = .round
        mintBot.setStroke()
        path.stroke()
    }

    // Pulse dot (top)
    do {
        let r = s * 0.0375
        let dot = NSBezierPath(ovalIn: CGRect(x: c.x - r, y: s - s * 0.21 - r, width: 2*r, height: 2*r))
        NSColor(srgbRed: 0, green: 0.94, blue: 0.71, alpha: 1).setFill()
        dot.fill()
    }

    // Center filled dot
    do {
        let r = s * 0.0625
        let dot = NSBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: 2*r, height: 2*r))
        let gradient = NSGradient(colors: [mintTop, mintBot])!
        gradient.draw(in: dot, angle: 270)
    }

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
    try writePNG(img, to: outDir.appendingPathComponent(name))
    print("✓ \(name) (\(size)×\(size))")
}
print("\nRun: iconutil -c icns \(outDir.path) -o Tools/AppIcon.icns")
