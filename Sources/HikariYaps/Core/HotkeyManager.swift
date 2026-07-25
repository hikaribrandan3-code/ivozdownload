import AppKit

/// Watches for the dictation hotkey system-wide (hold or tap behavior) using
/// NSEvent global + local monitors. Requires Accessibility permission.
@MainActor
final class HotkeyManager: ObservableObject {
    var onHoldStart: (() -> Void)?
    /// `cancelled` is true when the press looked like a keyboard shortcut
    /// (another key was hit while held) or was too short to be intentional.
    var onHoldEnd: ((_ cancelled: Bool) -> Void)?
    var onTapToggle: (() -> Void)?
    var onEscape: (() -> Void)?
    /// Fires in capture mode when the user presses a supported modifier.
    var onCaptured: ((HotkeyKey) -> Void)?

    @Published var isCapturing = false

    private let settings: SettingsStore
    private var monitors: [Any] = []
    private var modifierIsDown = false
    private var pressStartedAt: Date?
    private var otherKeyDuringHold = false

    private static let minimumHoldSeconds: TimeInterval = 0.25
    private static let maximumTapSeconds: TimeInterval = 0.4

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        stop()
        let flagsGlobal = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event) }
        }
        let keysGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handleKeyDown(event) }
        }
        let flagsLocal = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        let keysLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }
        monitors = [flagsGlobal, keysGlobal, flagsLocal, keysLocal].compactMap { $0 }
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
        modifierIsDown = false
        pressStartedAt = nil
    }

    func beginCapture() { isCapturing = true }
    func cancelCapture() { isCapturing = false }

    // MARK: - Event handling

    private func handleFlagsChanged(_ event: NSEvent) {
        if isCapturing {
            if let captured = HotkeyKey.from(keyCode: event.keyCode),
               event.modifierFlags.contains(captured.modifierFlag) {
                isCapturing = false
                onCaptured?(captured)
            }
            return
        }

        let hotkey = settings.hotkeyKey
        guard hotkey.keyCodes.contains(event.keyCode) else {
            // A different modifier moved. If it was pressed during our hold,
            // the user is doing a shortcut chord — cancel.
            if modifierIsDown, eventIndicatesOtherModifierPress(event) {
                otherKeyDuringHold = true
                if settings.hotkeyBehavior == .hold {
                    finishHold()
                }
            }
            return
        }

        let isPressed = event.modifierFlags.contains(hotkey.modifierFlag)
        if isPressed && !modifierIsDown {
            modifierIsDown = true
            otherKeyDuringHold = false
            pressStartedAt = Date()
            if settings.hotkeyBehavior == .hold {
                onHoldStart?()
            }
        } else if !isPressed && modifierIsDown {
            modifierIsDown = false
            switch settings.hotkeyBehavior {
            case .hold:
                finishHold()
            case .tap:
                let duration = -(pressStartedAt?.timeIntervalSinceNow ?? 1)
                if !otherKeyDuringHold && duration <= Self.maximumTapSeconds {
                    onTapToggle?()
                }
            }
            pressStartedAt = nil
        }
    }

    private func finishHold() {
        guard settings.hotkeyBehavior == .hold, pressStartedAt != nil else { return }
        let duration = -(pressStartedAt?.timeIntervalSinceNow ?? 1)
        let cancelled = otherKeyDuringHold || duration < Self.minimumHoldSeconds
        pressStartedAt = nil
        modifierIsDown = false
        onHoldEnd?(cancelled)
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onEscape?()
        }
        if modifierIsDown {
            // Typing while the modifier is held means a keyboard shortcut
            // (e.g. Ctrl+C), not dictation.
            otherKeyDuringHold = true
            if settings.hotkeyBehavior == .hold {
                finishHold()
            }
        }
    }

    private func eventIndicatesOtherModifierPress(_ event: NSEvent) -> Bool {
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let active = event.modifierFlags.intersection(relevant)
        return !active.subtracting(settings.hotkeyKey.modifierFlag).isEmpty
    }
}
