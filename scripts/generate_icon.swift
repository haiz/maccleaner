#!/usr/bin/env swift
import AppKit

func drawSegment(center: NSPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: center)
    path.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
    path.close()
    color.setFill()
    path.fill()
    NSColor(red: 0.08, green: 0.10, blue: 0.25, alpha: 1.0).setStroke()
    path.lineWidth = 3
    path.stroke()
}

func drawSparkle(at point: NSPoint, size: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: point.x, y: point.y + size))
    path.line(to: NSPoint(x: point.x + size * 0.2, y: point.y + size * 0.2))
    path.line(to: NSPoint(x: point.x + size, y: point.y))
    path.line(to: NSPoint(x: point.x + size * 0.2, y: point.y - size * 0.2))
    path.line(to: NSPoint(x: point.x, y: point.y - size))
    path.line(to: NSPoint(x: point.x - size * 0.2, y: point.y - size * 0.2))
    path.line(to: NSPoint(x: point.x - size, y: point.y))
    path.line(to: NSPoint(x: point.x - size * 0.2, y: point.y + size * 0.2))
    path.close()
    NSColor(white: 1.0, alpha: 0.8).setFill()
    path.fill()
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    let iconPath = NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40), xRadius: 200, yRadius: 200)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.08, green: 0.10, blue: 0.25, alpha: 1.0),
        NSColor(red: 0.05, green: 0.20, blue: 0.35, alpha: 1.0),
    ])!
    gradient.draw(in: iconPath, angle: -45)

    let innerRect = rect.insetBy(dx: 44, dy: 44)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 196, yRadius: 196)
    NSColor(white: 1.0, alpha: 0.03).setStroke()
    innerPath.lineWidth = 4
    innerPath.stroke()

    let center = NSPoint(x: rect.midX - 20, y: rect.midY + 40)
    let radius: CGFloat = 280

    drawSegment(center: center, radius: radius, startAngle: 0, endAngle: 160,
                color: NSColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 0.9))
    drawSegment(center: center, radius: radius, startAngle: 160, endAngle: 220,
                color: NSColor(red: 1.0, green: 0.63, blue: 0.42, alpha: 0.9))
    drawSegment(center: center, radius: radius, startAngle: 220, endAngle: 290,
                color: NSColor(red: 0.49, green: 0.54, blue: 1.0, alpha: 0.9))
    drawSegment(center: center, radius: radius, startAngle: 290, endAngle: 360,
                color: NSColor(red: 0.42, green: 1.0, blue: 0.76, alpha: 0.9))

    let holePath = NSBezierPath(ovalIn: NSRect(x: center.x - 120, y: center.y - 120, width: 240, height: 240))
    NSColor(red: 0.08, green: 0.10, blue: 0.25, alpha: 1.0).setFill()
    holePath.fill()

    let mgCenter = NSPoint(x: rect.midX + 160, y: rect.midY - 160)
    let mgRadius: CGFloat = 110

    let glassPath = NSBezierPath(ovalIn: NSRect(
        x: mgCenter.x - mgRadius, y: mgCenter.y - mgRadius,
        width: mgRadius * 2, height: mgRadius * 2
    ))
    NSColor(white: 1.0, alpha: 0.15).setFill()
    glassPath.fill()
    NSColor(white: 1.0, alpha: 0.6).setStroke()
    glassPath.lineWidth = 16
    glassPath.stroke()

    let handlePath = NSBezierPath()
    handlePath.move(to: NSPoint(x: mgCenter.x + mgRadius * 0.6, y: mgCenter.y - mgRadius * 0.6))
    handlePath.line(to: NSPoint(x: mgCenter.x + mgRadius * 1.2, y: mgCenter.y - mgRadius * 1.2))
    NSColor(white: 1.0, alpha: 0.6).setStroke()
    handlePath.lineWidth = 20
    handlePath.lineCapStyle = .round
    handlePath.stroke()

    drawSparkle(at: NSPoint(x: rect.midX + 240, y: rect.midY + 240), size: 60)
    drawSparkle(at: NSPoint(x: rect.midX + 310, y: rect.midY + 180), size: 36)

    return true
}

// Export as PNG
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon.png"
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to render icon")
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Icon written to \(outputPath)")
