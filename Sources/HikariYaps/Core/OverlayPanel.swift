import AppKit
import SwiftUI

/// A borderless HUD panel that can never become the key window.
///
/// `.nonactivatingPanel` in the style mask only stops the *owning app* from
/// becoming frontmost when the panel is shown — it does not stop the panel
/// itself from becoming *key*, which is a separate AppKit/WindowServer
/// concept. A panel that's key (even while its app isn't frontmost per
/// `NSWorkspace`) is what raw HID keystrokes and the system-wide AX focused
/// element both route to. `becomesKeyOnlyIfNeeded` only narrows *when* that
/// can happen — it doesn't prevent it, and `NSHostingView`-hosted SwiftUI
/// content can trigger it without any click. This is exactly how dictation
/// was landing back inside Hikari Yaps: the target app was still correctly
/// "frontmost," but this panel had quietly become "key" underneath it.
/// Overriding `canBecomeKey` closes that off categorically.
private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Borderless, non-activating floating panel that shows recording status and
/// the live waveform near the bottom of the screen. Never steals focus from
/// the app being dictated into.
@MainActor
final class OverlayPanel {
    private var panel: NSPanel?
    private weak var controller: DictationController?

    init(controller: DictationController) {
        self.controller = controller
        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.repositionIfNeeded()
            }
        }
    }

    private func repositionIfNeeded() {
        guard let panel else { return }
        position(panel)
    }

    func update(for phase: OverlayPhase) {
        if phase == .hidden {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        if panel == nil {
            createPanel()
            guard let panel else { return }
            position(panel)
        }
        guard let panel else { return }
        position(panel) // Reposition every time to lock bottom-center
        panel.orderFrontRegardless()
        panel.animator().alphaValue = 1
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func createPanel() {
        guard let controller else { return }

        // Fixed size: 62px pill, Haiku button height (32px)
        let panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        // becomesKeyOnlyIfNeeded is moot now — canBecomeKey is hard-false above.

        let host = NSHostingView(rootView: OverlayView(controller: controller))
        host.frame = panel.contentRect(forFrameRect: panel.frame)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        self.panel = panel
    }

    private func position(_ panel: NSPanel) {
        // screens[0] is always the display holding the menu bar (the
        // physical primary display in System Settings > Displays) —
        // stable regardless of which window currently has focus.
        // NSScreen.main tracks the *key window's* screen instead, so on
        // a multi-monitor setup it silently follows focus across displays;
        // screens[0] never does.
        guard let screen = NSScreen.screens.first else { return }
        let frame = screen.frame
        let size = panel.frame.size
        // Center horizontally, 1 inch from the physical bottom edge (72pt).
        // Anchored to the full screen frame, not visibleFrame, so Dock
        // auto-hide/show toggling doesn't shift the pill up and down.
        let x = frame.minX + (frame.width - size.width) / 2.0
        let y = frame.minY + 72.0
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
