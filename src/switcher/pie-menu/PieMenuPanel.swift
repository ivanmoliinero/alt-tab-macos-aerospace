import Cocoa

/// Floating NSPanel hosting the radial PieMenuView.
final class PieMenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    static var shared: PieMenuPanel!

    let view = PieMenuView()

    convenience init() {
        let size = NSSize(width: PieMenuView.canvasDiameter, height: PieMenuView.canvasDiameter)
        self.init(contentRect: NSRect(origin: .zero, size: size),
                  styleMask: .nonactivatingPanel,
                  backing: .buffered,
                  defer: false)
        applyFloatingPanelChrome()
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        contentView = view
        setAccessibilityLabel("Pie Menu Switcher")
        Self.shared = self
    }

    /// Positions and presents the pie menu centered either at the mouse cursor or screen center.
    func show() {
        MainThreadStall.step()
        guard SwitcherSession.isActive else {
            orderOut(nil)
            return
        }

        let size = NSSize(width: PieMenuView.canvasDiameter, height: PieMenuView.canvasDiameter)
        setContentSize(size)

        // Center on the active screen's visible area
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLoc) } ?? NSScreen.preferred
        let visibleFrame = screen.visibleFrame

        let originX = visibleFrame.midX - size.width / 2.0
        let originY = visibleFrame.midY - size.height / 2.0

        setFrameOrigin(NSPoint(x: originX, y: originY))

        view.reloadItems()

        // Double check session is still active after reload before ordering front
        guard SwitcherSession.isActive else {
            orderOut(nil)
            return
        }

        alphaValue = 1.0
        makeKeyAndOrderFront(nil)

        if let session = SwitcherSession.current, session.panelShownAt == nil {
            session.panelShownAt = ProcessInfo.processInfo.systemUptime
        }

        ContextMenuEvents.toggle(true)
        CursorEvents.toggle(true)
    }

    /// Updates item contents when window state changes.
    func updateContents() {
        guard SwitcherSession.isActive else { return }
        view.reloadItems()
    }

    /// Re-syncs the active slice selection from SwitcherSession.
    func updateSelection() {
        guard SwitcherSession.isActive else { return }
        view.syncSelectionFromSession()
    }

    /// Cycles the active window selection circularly in the pie menu.
    func cycleSelection(_ step: Int, allowWrap: Bool = true) {
        guard SwitcherSession.isActive else { return }
        view.stepSelection(step)
    }

    /// Forwards pointer movement to the hosted pie menu view.
    func handleMouseMoved() {
        guard SwitcherSession.isActive else { return }
        view.handleMouseMoved()
    }

    override func orderOut(_ sender: Any?) {
        MainThreadStall.step()
        alphaValue = 0.0
        super.orderOut(sender)
        if !SwitcherSession.isActive {
            ContextMenuEvents.toggle(false)
            CursorEvents.toggle(false)
        }
    }
}
