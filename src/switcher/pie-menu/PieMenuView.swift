import Cocoa

/// Model for an individual slice in the radial pie menu.
struct PieMenuItem {
    let window: Window
    let listIndex: Int
    let midAngle: CGFloat
    let startAngle: CGFloat
    let endAngle: CGFloat
}

/// Dynamic, interactive radial pie menu view for AltTab with AeroSpace integration.
final class PieMenuView: NSView {
    override var isFlipped: Bool { false }

    private(set) var items: [PieMenuItem] = []
    private(set) var selectedItemIndex: Int = 0

    /// Base diameter of the pie menu canvas.
    static let canvasDiameter: CGFloat = 580.0

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: Self.canvasDiameter, height: Self.canvasDiameter)))
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    // MARK: - Layout & Geometry

    var centerPoint: NSPoint {
        NSPoint(x: bounds.midX, y: bounds.midY)
    }

    var outerRadius: CGFloat {
        (min(bounds.width, bounds.height) / 2.0) - 18.0
    }

    var innerRadius: CGFloat {
        outerRadius * 0.42
    }

    // MARK: - Data Synchronization

    /// Reloads window items from the current AeroSpace-filtered Windows list.
    func reloadItems() {
        let rawDisplayed = Windows.list.enumerated().filter { Windows.shouldDisplay($0.element) }
        guard !rawDisplayed.isEmpty else {
            items = []
            selectedItemIndex = 0
            needsDisplay = true
            return
        }

        // Order windows strictly by their position in AeroSpace's layout tree
        let aerospaceOrder = AeroSpaceWindows.focusedWorkspaceWindowIds() ?? []
        let displayedWindows = rawDisplayed.sorted { a, b in
            let posA = a.element.cgWindowId.flatMap { aerospaceOrder.firstIndex(of: $0) } ?? Int.max
            let posB = b.element.cgWindowId.flatMap { aerospaceOrder.firstIndex(of: $0) } ?? Int.max
            if posA != posB {
                return posA < posB
            }
            return a.offset < b.offset
        }

        let count = displayedWindows.count
        let angleDelta = (2.0 * CGFloat.pi) / CGFloat(count)
        // Leave a slight gap between slices when there are multiple items
        let gapAngle: CGFloat = count > 1 ? min(0.045, 0.4 / CGFloat(count)) : 0.0

        items = displayedWindows.enumerated().map { (sliceIndex, element) in
            // Place item 0 at 12 o'clock (pi / 2), progressing clockwise
            let midAngle = (CGFloat.pi / 2.0) - CGFloat(sliceIndex) * angleDelta
            let halfAngle = (angleDelta / 2.0) - (gapAngle / 2.0)
            let start = midAngle + halfAngle // Counter-clockwise boundary (higher angle)
            let end = midAngle - halfAngle   // Clockwise boundary (lower angle)
            return PieMenuItem(
                window: element.element,
                listIndex: element.offset,
                midAngle: midAngle,
                startAngle: start,
                endAngle: end
            )
        }

        syncSelectionFromSession()
        needsDisplay = true
    }

    /// Syncs the selected slice from SwitcherSession.current.
    func syncSelectionFromSession() {
        guard let session = SwitcherSession.current, !items.isEmpty else {
            selectedItemIndex = 0
            return
        }

        if let matchingIndex = items.firstIndex(where: { $0.listIndex == session.selectedIndex }) {
            selectedItemIndex = matchingIndex
        } else {
            selectedItemIndex = min(max(0, session.selectedIndex), items.count - 1)
            let currentItem = items[selectedItemIndex]
            session.selectedIndex = currentItem.listIndex
            session.selectedTarget = currentItem.window.id
        }
        needsDisplay = true
    }

    /// Advances the selection circularly.
    func stepSelection(_ step: Int) {
        guard !items.isEmpty else { return }
        let newIndex = (selectedItemIndex + step + items.count) % items.count
        selectIndex(newIndex)
    }

    private func selectIndex(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedItemIndex = index
        let item = items[index]
        if let session = SwitcherSession.current {
            session.selectedIndex = item.listIndex
            session.selectedTarget = item.window.id
            session.userPickedSelection = true
        }
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let center = centerPoint
        let outerR = outerRadius
        let innerR = innerRadius

        // 1. Draw outer circular shadow / glow ring
        drawOuterBackdrop(in: context, center: center, radius: outerR)

        // 2. Draw slices
        if items.isEmpty {
            drawEmptyState(in: context, center: center, innerRadius: innerR)
            return
        }

        for (index, item) in items.enumerated() {
            let isSelected = (index == selectedItemIndex)
            drawWedge(in: context, center: center, innerRadius: innerR, outerRadius: outerR,
                      item: item, isSelected: isSelected)
        }

        // 3. Draw Center Hub (Donut Hole)
        drawCenterHub(in: context, center: center, innerRadius: innerR)
    }

    private func drawOuterBackdrop(in context: CGContext, center: NSPoint, radius: CGFloat) {
        context.saveGState()
        let backdropPath = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                       width: radius * 2.0, height: radius * 2.0))
        // Translucent dark glass backdrop
        NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 0.72).setFill()
        backdropPath.fill()

        NSColor(calibratedWhite: 1.0, alpha: 0.12).setStroke()
        backdropPath.lineWidth = 1.0
        backdropPath.stroke()
        context.restoreGState()
    }

    private func drawWedge(in context: CGContext, center: NSPoint, innerRadius: CGFloat, outerRadius: CGFloat,
                           item: PieMenuItem, isSelected: Bool) {
        context.saveGState()

        let wedgePath = NSBezierPath()
        if items.count == 1 {
            // Full circle donut
            wedgePath.appendArc(withCenter: center, radius: outerRadius, startAngle: 0, endAngle: 360)
            wedgePath.appendArc(withCenter: center, radius: innerRadius, startAngle: 360, endAngle: 0, clockwise: true)
            wedgePath.close()
        } else {
            let startDeg = item.startAngle * 180.0 / .pi
            let endDeg = item.endAngle * 180.0 / .pi
            // Outer arc: sweep clockwise from startAngle (CCW edge) to endAngle (CW edge)
            wedgePath.appendArc(withCenter: center, radius: outerRadius,
                                startAngle: startDeg, endAngle: endDeg, clockwise: true)
            // Inner arc: return counter-clockwise from endAngle to startAngle
            wedgePath.appendArc(withCenter: center, radius: innerRadius,
                                startAngle: endDeg, endAngle: startDeg, clockwise: false)
            wedgePath.close()
        }

        if isSelected {
            // Vibrant accent highlight fill
            NSColor.controlAccentColor.withAlphaComponent(0.85).setFill()
            wedgePath.fill()

            // Crisp inner highlight border
            NSColor.white.withAlphaComponent(0.65).setStroke()
            wedgePath.lineWidth = 2.0
            wedgePath.stroke()
        } else {
            // Unselected wedge fill
            NSColor(calibratedWhite: 1.0, alpha: 0.08).setFill()
            wedgePath.fill()

            NSColor(calibratedWhite: 1.0, alpha: 0.06).setStroke()
            wedgePath.lineWidth = 0.5
            wedgePath.stroke()
        }

        // Draw icon & title on the wedge
        let midR = (innerRadius + outerRadius) / 2.0
        let iconCenter = NSPoint(x: center.x + midR * cos(item.midAngle),
                                 y: center.y + midR * sin(item.midAngle))

        let iconSize: CGFloat = items.count > 10 ? 32.0 : 40.0
        let iconRect = NSRect(x: iconCenter.x - iconSize / 2.0,
                              y: iconCenter.y - (items.count > 6 ? iconSize / 2.0 : (iconSize / 2.0 - 5.0)),
                              width: iconSize,
                              height: iconSize)

        // Render application icon
        if let cgIcon = item.window.icon {
            let nsImage = NSImage(cgImage: cgIcon, size: iconRect.size)
            let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 7.0, yRadius: 7.0)
            context.saveGState()
            iconPath.addClip()
            nsImage.draw(in: iconRect)
            context.restoreGState()

            // Subtle icon outline
            NSColor(calibratedWhite: 1.0, alpha: 0.25).setStroke()
            iconPath.lineWidth = 1.0
            iconPath.stroke()
        }

        // Draw brief label below icon when space permits (<= 8 items)
        if items.count <= 8 {
            let appName = item.window.application.runningApplication.localizedName ?? ""
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10.5, weight: isSelected ? .bold : .medium),
                .foregroundColor: isSelected ? NSColor.white : NSColor(calibratedWhite: 0.95, alpha: 0.85)
            ]
            let attributedString = NSAttributedString(string: appName, attributes: textAttributes)
            let textSize = attributedString.size()
            let maxLabelWidth: CGFloat = (outerRadius - innerRadius) * 0.95
            let labelWidth = min(textSize.width, maxLabelWidth)
            let labelRect = NSRect(x: iconCenter.x - labelWidth / 2.0,
                                   y: iconRect.minY - 14.0,
                                   width: labelWidth,
                                   height: 13.0)
            attributedString.draw(with: labelRect, options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin])
        }

        context.restoreGState()
    }

    private func drawCenterHub(in context: CGContext, center: NSPoint, innerRadius: CGFloat) {
        context.saveGState()
        let hubRadius = innerRadius - 2.5
        let hubRect = NSRect(x: center.x - hubRadius, y: center.y - hubRadius,
                             width: hubRadius * 2.0, height: hubRadius * 2.0)
        let hubPath = NSBezierPath(ovalIn: hubRect)

        // Solid glass hub fill
        NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.16, alpha: 0.96).setFill()
        hubPath.fill()

        // Hub border
        NSColor.controlAccentColor.withAlphaComponent(0.45).setStroke()
        hubPath.lineWidth = 1.5
        hubPath.stroke()

        guard items.indices.contains(selectedItemIndex) else {
            context.restoreGState()
            return
        }

        let selectedWindow = items[selectedItemIndex].window

        // Draw Selected Window details inside the hub
        let appName = selectedWindow.application.runningApplication.localizedName ?? ""
        let windowTitle = selectedWindow.title.isEmpty ? appName : selectedWindow.title
        let aerospaceWorkspace = selectedWindow.aerospaceId

        // Hub icon (centered near top of hub)
        let hubIconSize: CGFloat = 36.0
        let hubIconRect = NSRect(x: center.x - hubIconSize / 2.0,
                                 y: center.y + 14.0,
                                 width: hubIconSize,
                                 height: hubIconSize)
        if let cgIcon = selectedWindow.icon {
            let nsImage = NSImage(cgImage: cgIcon, size: hubIconRect.size)
            let iconPath = NSBezierPath(roundedRect: hubIconRect, xRadius: 7.0, yRadius: 7.0)
            context.saveGState()
            iconPath.addClip()
            nsImage.draw(in: hubIconRect)
            context.restoreGState()

            NSColor(calibratedWhite: 1.0, alpha: 0.2).setStroke()
            iconPath.lineWidth = 1.0
            iconPath.stroke()
        }

        // App Name (bold)
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.0, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let nameString = NSAttributedString(string: appName, attributes: nameAttributes)
        let nameWidth = min(nameString.size().width, (hubRadius * 2.0) - 24.0)
        let nameRect = NSRect(x: center.x - nameWidth / 2.0, y: center.y - 7.0,
                              width: nameWidth, height: 16.0)
        nameString.draw(with: nameRect, options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin])

        // Window Title (truncated)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.85, alpha: 0.85)
        ]
        let titleString = NSAttributedString(string: windowTitle, attributes: titleAttributes)
        let titleWidth = min(titleString.size().width, (hubRadius * 2.0) - 24.0)
        let titleRect = NSRect(x: center.x - titleWidth / 2.0, y: center.y - 25.0,
                               width: titleWidth, height: 14.0)
        titleString.draw(with: titleRect, options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin])

        // AeroSpace workspace badge
        if let ws = aerospaceWorkspace, !ws.isEmpty {
            let badgeText = "Workspace \(ws)"
            let badgeAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9.0, weight: .semibold),
                .foregroundColor: NSColor.controlAccentColor
            ]
            let badgeString = NSAttributedString(string: badgeText, attributes: badgeAttributes)
            let badgeTextWidth = badgeString.size().width
            let badgePillRect = NSRect(x: center.x - (badgeTextWidth + 14.0) / 2.0,
                                       y: center.y - 45.0,
                                       width: badgeTextWidth + 14.0,
                                       height: 15.0)
            let pillPath = NSBezierPath(roundedRect: badgePillRect, xRadius: 7.5, yRadius: 7.5)
            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            pillPath.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.35).setStroke()
            pillPath.lineWidth = 0.5
            pillPath.stroke()

            badgeString.draw(at: NSPoint(x: badgePillRect.minX + 7.0, y: badgePillRect.minY + 1.5))
        }

        context.restoreGState()
    }

    private func drawEmptyState(in context: CGContext, center: NSPoint, innerRadius: CGFloat) {
        context.saveGState()
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.0, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.8, alpha: 0.9)
        ]
        let emptyText = NSAttributedString(string: NSLocalizedString("No Windows in Workspace", comment: ""),
                                           attributes: textAttributes)
        let size = emptyText.size()
        emptyText.draw(at: NSPoint(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0))
        context.restoreGState()
    }

    // MARK: - Mouse Event Handling

    /// Handles pointer movement using the window coordinate space.
    func handleMouseMoved() {
        guard let window else { return }
        let localPoint = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        handleLocalMousePoint(localPoint)
    }

    /// Handles pointer movement forwarded from screen coordinates.
    func handleMouseMoved(screenPoint: CGPoint) {
        handleMouseMoved()
    }

    func handleLocalMousePoint(_ point: NSPoint) {
        guard !items.isEmpty else { return }
        let center = centerPoint
        let deltaX = point.x - center.x
        let deltaY = point.y - center.y
        let distance = hypot(deltaX, deltaY)

        // Ignore movements too deep inside the center hub or far outside the wheel
        guard distance >= (innerRadius * 0.55) && distance <= (outerRadius + 30.0) else {
            return
        }

        let mouseAngle = normalizeAngle(atan2(deltaY, deltaX))

        var closestIndex = selectedItemIndex
        var minDiff = CGFloat.greatestFiniteMagnitude

        for (i, item) in items.enumerated() {
            let normalizedMid = normalizeAngle(item.midAngle)
            var diff = abs(mouseAngle - normalizedMid)
            if diff > .pi {
                diff = (2.0 * .pi) - diff
            }
            if diff < minDiff {
                minDiff = diff
                closestIndex = i
            }
        }

        if closestIndex != selectedItemIndex {
            selectIndex(closestIndex)
        }
    }

    private func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        let twoPi = 2.0 * CGFloat.pi
        var normalized = angle.truncatingRemainder(dividingBy: twoPi)
        if normalized < 0 {
            normalized += twoPi
        }
        return normalized
    }

    override func mouseMoved(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        handleLocalMousePoint(localPoint)
    }

    override func mouseUp(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let distance = hypot(localPoint.x - centerPoint.x, localPoint.y - centerPoint.y)
        if distance <= (outerRadius + 20.0) {
            App.focusTarget()
        } else {
            App.hideUi()
        }
    }

    // MARK: - Keyboard Event Handling

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 48: // Tab
            let isShift = event.modifierFlags.contains(.shift)
            stepSelection(isShift ? -1 : 1)
        case 123, 126: // Left or Up Arrow (counter-clockwise / previous sector)
            stepSelection(-1)
        case 124, 125: // Right or Down Arrow (clockwise / next sector)
            stepSelection(1)
        case 36, 49: // Return or Space
            App.focusTarget()
        case 53: // Escape
            App.hideUi()
        default:
            super.keyDown(with: event)
        }
    }
}
