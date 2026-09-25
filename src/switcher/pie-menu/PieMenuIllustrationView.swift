import Cocoa

/// Static preview and drawing helper for the Pie Menu style in settings.
final class PieMenuIllustrationView: NSView {
    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        Self.drawIllustration(in: bounds, context: context)
    }

    /// Generates an NSImage representation of the pie menu preview for use in radio buttons or sheets.
    static func renderPreviewImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            drawIllustration(in: NSRect(origin: .zero, size: size), context: context)
        }
        image.unlockFocus()
        return image
    }

    /// Renders a modern, high-fidelity radial switcher mockup.
    private static func drawIllustration(in rect: NSRect, context: CGContext) {
        context.saveGState()

        // 1. Draw rounded card background
        let cardRadius: CGFloat = 8.0
        let cardPath = NSBezierPath(roundedRect: rect, xRadius: cardRadius, yRadius: cardRadius)
        NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1.0).setFill()
        cardPath.fill()

        // Subtle card border
        NSColor(calibratedWhite: 1.0, alpha: 0.1).setStroke()
        cardPath.lineWidth = 1.0
        cardPath.stroke()

        // 2. Wheel geometry
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let outerRadius: CGFloat = min(rect.width, rect.height) * 0.38
        let innerRadius: CGFloat = outerRadius * 0.42
        let sliceCount = 6
        let angleDelta = (2.0 * CGFloat.pi) / CGFloat(sliceCount)
        let gapAngle = 0.05 // radians between slices

        // 3. Draw radial slices
        for i in 0..<sliceCount {
            let midAngle = (CGFloat.pi / 2.0) - CGFloat(i) * angleDelta
            let start = midAngle + (angleDelta / 2.0) - (gapAngle / 2.0)
            let end = midAngle - (angleDelta / 2.0) + (gapAngle / 2.0)

            let slicePath = NSBezierPath()
            // Outer arc (counter-clockwise from end to start)
            slicePath.appendArc(withCenter: center, radius: outerRadius,
                                startAngle: end * 180.0 / .pi,
                                endAngle: start * 180.0 / .pi,
                                clockwise: false)
            // Inner arc (clockwise back from start to end)
            slicePath.appendArc(withCenter: center, radius: innerRadius,
                                startAngle: start * 180.0 / .pi,
                                endAngle: end * 180.0 / .pi,
                                clockwise: true)
            slicePath.close()

            if i == 0 {
                // Highlighted slice (macOS Accent Blue)
                NSColor.controlAccentColor.setFill()
                slicePath.fill()

                NSColor.white.withAlphaComponent(0.4).setStroke()
                slicePath.lineWidth = 1.0
                slicePath.stroke()
            } else {
                // Unselected slices
                NSColor(calibratedWhite: 1.0, alpha: 0.12).setFill()
                slicePath.fill()

                NSColor(calibratedWhite: 1.0, alpha: 0.05).setStroke()
                slicePath.lineWidth = 0.5
                slicePath.stroke()
            }

            // Slice icon pip
            let pipRadius = (innerRadius + outerRadius) / 2.0
            let pipCenter = NSPoint(x: center.x + pipRadius * cos(midAngle),
                                    y: center.y + pipRadius * sin(midAngle))
            let pipSize: CGFloat = i == 0 ? 5.5 : 4.0
            let pipRect = NSRect(x: pipCenter.x - pipSize / 2.0,
                                 y: pipCenter.y - pipSize / 2.0,
                                 width: pipSize,
                                 height: pipSize)
            let pipPath = NSBezierPath(ovalIn: pipRect)
            if i == 0 {
                NSColor.white.setFill()
            } else {
                NSColor(calibratedWhite: 1.0, alpha: 0.5).setFill()
            }
            pipPath.fill()
        }

        // 4. Center hub (donut hole)
        let hubPath = NSBezierPath(ovalIn: NSRect(x: center.x - innerRadius + 2.0,
                                                 y: center.y - innerRadius + 2.0,
                                                 width: (innerRadius - 2.0) * 2.0,
                                                 height: (innerRadius - 2.0) * 2.0))
        NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.12, alpha: 1.0).setFill()
        hubPath.fill()
        NSColor(calibratedWhite: 1.0, alpha: 0.15).setStroke()
        hubPath.lineWidth = 1.0
        hubPath.stroke()

        // Tiny center indicator dot
        let centerDotSize: CGFloat = 3.5
        let centerDotPath = NSBezierPath(ovalIn: NSRect(x: center.x - centerDotSize / 2.0,
                                                       y: center.y - centerDotSize / 2.0,
                                                       width: centerDotSize,
                                                       height: centerDotSize))
        NSColor.controlAccentColor.setFill()
        centerDotPath.fill()

        context.restoreGState()
    }
}
