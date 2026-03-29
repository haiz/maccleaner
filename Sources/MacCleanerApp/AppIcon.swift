import AppKit

/// Generates and sets the app's dock icon programmatically.
/// Uses a modern gradient disk + magnifying glass design.
enum AppIconGenerator {

    static func setDockIcon() {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size, flipped: false) { rect in
            // Background: rounded square (macOS icon shape)
            let iconPath = NSBezierPath(roundedRect: rect.insetBy(dx: 20, dy: 20), xRadius: 100, yRadius: 100)

            // Gradient background: deep blue to teal
            let gradient = NSGradient(colors: [
                NSColor(red: 0.08, green: 0.10, blue: 0.25, alpha: 1.0),
                NSColor(red: 0.05, green: 0.20, blue: 0.35, alpha: 1.0),
            ])!
            gradient.draw(in: iconPath, angle: -45)

            // Subtle inner shadow
            let innerRect = rect.insetBy(dx: 22, dy: 22)
            let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 98, yRadius: 98)
            NSColor(white: 1.0, alpha: 0.03).setStroke()
            innerPath.lineWidth = 2
            innerPath.stroke()

            // Disk pie chart
            let center = NSPoint(x: rect.midX - 10, y: rect.midY + 20)
            let radius: CGFloat = 140

            // Segment 1: Red (System Data — largest)
            drawSegment(center: center, radius: radius, startAngle: 0, endAngle: 160,
                       color: NSColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 0.9))

            // Segment 2: Orange (Apps)
            drawSegment(center: center, radius: radius, startAngle: 160, endAngle: 220,
                       color: NSColor(red: 1.0, green: 0.63, blue: 0.42, alpha: 0.9))

            // Segment 3: Blue (Developer)
            drawSegment(center: center, radius: radius, startAngle: 220, endAngle: 290,
                       color: NSColor(red: 0.49, green: 0.54, blue: 1.0, alpha: 0.9))

            // Segment 4: Green (Free space)
            drawSegment(center: center, radius: radius, startAngle: 290, endAngle: 360,
                       color: NSColor(red: 0.42, green: 1.0, blue: 0.76, alpha: 0.9))

            // Inner circle (donut hole)
            let holePath = NSBezierPath(ovalIn: NSRect(
                x: center.x - 60, y: center.y - 60, width: 120, height: 120
            ))
            NSColor(red: 0.08, green: 0.10, blue: 0.25, alpha: 1.0).setFill()
            holePath.fill()

            // Magnifying glass overlay (bottom-right)
            let mgCenter = NSPoint(x: rect.midX + 80, y: rect.midY - 80)
            let mgRadius: CGFloat = 55

            // Glass circle
            let glassPath = NSBezierPath(ovalIn: NSRect(
                x: mgCenter.x - mgRadius, y: mgCenter.y - mgRadius,
                width: mgRadius * 2, height: mgRadius * 2
            ))
            NSColor(white: 1.0, alpha: 0.15).setFill()
            glassPath.fill()
            NSColor(white: 1.0, alpha: 0.6).setStroke()
            glassPath.lineWidth = 8
            glassPath.stroke()

            // Handle
            let handlePath = NSBezierPath()
            handlePath.move(to: NSPoint(x: mgCenter.x + mgRadius * 0.6, y: mgCenter.y - mgRadius * 0.6))
            handlePath.line(to: NSPoint(x: mgCenter.x + mgRadius * 1.2, y: mgCenter.y - mgRadius * 1.2))
            NSColor(white: 1.0, alpha: 0.6).setStroke()
            handlePath.lineWidth = 10
            handlePath.lineCapStyle = .round
            handlePath.stroke()

            // Sparkle / clean indicator (top-right)
            drawSparkle(at: NSPoint(x: rect.midX + 120, y: rect.midY + 120), size: 30)
            drawSparkle(at: NSPoint(x: rect.midX + 155, y: rect.midY + 90), size: 18)

            return true
        }

        NSApplication.shared.applicationIconImage = image
    }

    private static func drawSegment(center: NSPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: center)
        path.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.close()
        color.setFill()
        path.fill()

        // Gap line between segments
        NSColor(red: 0.08, green: 0.10, blue: 0.25, alpha: 1.0).setStroke()
        path.lineWidth = 3
        path.stroke()
    }

    private static func drawSparkle(at point: NSPoint, size: CGFloat) {
        let path = NSBezierPath()
        // 4-pointed star
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
}
