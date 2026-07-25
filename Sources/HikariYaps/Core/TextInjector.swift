import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os

enum InjectionResult {
    case injected
    case leftOnClipboard(reason: String)
}

/// Inserts text into whatever app was frontmost when dictation started.
///
/// Cascade (method `.auto`, the default): Accessibility API insertion at the
/// caret → CGEvent keystroke simulation → clipboard + synthesized ⌘V. Each
/// strategy falls through to the next on failure. `.paste`/`.type` pin a
/// specific mechanism for users who've explicitly chosen one.
///
/// The critical fix this class implements: the app that was frontmost when
/// the hotkey was pressed is captured by `DictationController` and passed in
/// as `target`. Without re-affirming that target right before injecting,
/// whatever window happens to be key *at completion time* — which can drift
/// during the async transcribe/cleanup pipeline — receives the text instead,
/// which is how transcripts were ending up inside iVoz itself.
@MainActor
final class TextInjector {

    private let logger = Logger(subsystem: "com.hikari.yaps", category: "injection")

    private var lastInjectionTime: Date?
    private static let minInjectionInterval: TimeInterval = 0.15
    /// Beyond this length, prefer paste over character-by-character typing —
    /// a multi-second synthetic keystroke burst is worse than an instant paste.
    private static let typeStrategyCharLimit = 500

    /// Injects `text`, targeting the app that was frontmost when dictation
    /// started (`target`). Requires Accessibility permission.
    func inject(_ text: String, method: InjectionMethod, target: NSRunningApplication?) async -> InjectionResult {
        // 1. Secure input (password fields) blocks synthetic events entirely.
        if IsSecureEventInputEnabled() {
            logger.notice("blocked: secure event input enabled system-wide, chars=\(text.count, privacy: .public)")
            return leaveOnClipboard(text, reason: L("injector.secure_field"))
        }

        // 2. Accessibility permission is required for both AX writes and
        // CGEvent synthesis.
        let hasAX = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
        if !hasAX {
            logger.notice("blocked: accessibility not trusted, chars=\(text.count, privacy: .public)")
            return leaveOnClipboard(text, reason: L("injector.accessibility_needed"))
        }

        // 3. Throttle rapid injections.
        if let last = lastInjectionTime, Date().timeIntervalSince(last) < Self.minInjectionInterval {
            try? await Task.sleep(nanoseconds: UInt64(Self.minInjectionInterval * 1_000_000_000))
        }
        lastInjectionTime = Date()

        // 4. Re-affirm the captured target is still frontmost, re-activating
        // it if something else drifted into focus while transcription and
        // cleanup ran. This is the actual bug fix — see class doc comment.
        switch await resolveTarget(target) {
        case .targetClosed:
            logger.notice("target app closed before injection, chars=\(text.count, privacy: .public)")
            return leaveOnClipboard(text, reason: L("injector.target_closed"))
        case .reactivateFailed:
            logger.notice("could not reactivate target app, chars=\(text.count, privacy: .public)")
            return leaveOnClipboard(text, reason: L("injector.reactivate_failed"))
        case .ready(let resolvedTarget):
            return await performInjection(text, method: method, target: resolvedTarget)
        }
    }

    // MARK: - Target resolution

    private enum TargetResolution {
        case ready(NSRunningApplication)
        case targetClosed
        case reactivateFailed
    }

    /// Confirms `target` is frontmost, re-activating it (and waiting briefly
    /// for the switch to land) if the frontmost app drifted during the async
    /// pipeline. Never activates *some other* app — only the one the user was
    /// in when they pressed the hotkey.
    private func resolveTarget(_ target: NSRunningApplication?) async -> TargetResolution {
        guard let target else {
            // No captured target (shouldn't normally happen) — best effort:
            // whatever is frontmost right now.
            guard let frontmost = NSWorkspace.shared.frontmostApplication else { return .reactivateFailed }
            return .ready(frontmost)
        }
        if target.isTerminated { return .targetClosed }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
            return .ready(target)
        }

        target.activate()
        for _ in 0..<15 { // ~300ms total, 20ms steps
            if target.isTerminated { return .targetClosed }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
                return .ready(target)
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return .reactivateFailed
    }

    // MARK: - Method routing

    private func performInjection(_ text: String, method: InjectionMethod, target: NSRunningApplication) async -> InjectionResult {
        let bundleID = target.bundleIdentifier ?? "unknown"

        switch method {
        case .paste:
            // Explicit user choice — always Strategy C, no AX/keystroke attempt.
            let ok = await strategyC(text, target: target)
            if ok { logSuccess(text: text, targetBundleID: bundleID, strategy: "C(forced)") }
            return ok ? .injected : .leftOnClipboard(reason: L("injector.accessibility_needed"))

        case .type:
            // Explicit user choice — Strategy B, falling back to C only if B
            // can't complete (too long, or the target lost focus mid-burst).
            if text.count <= Self.typeStrategyCharLimit {
                switch await strategyB(text, target: target) {
                case .completed:
                    logSuccess(text: text, targetBundleID: bundleID, strategy: "B(forced)")
                    return .injected
                case .partial(let remaining):
                    let ok = await strategyC(remaining, target: target)
                    if ok { logSuccess(text: text, targetBundleID: bundleID, strategy: "B(forced)+C(remainder)") }
                    return ok ? .injected : .leftOnClipboard(reason: L("injector.accessibility_needed"))
                case .failed:
                    break
                }
            }
            let ok = await strategyC(text, target: target)
            if ok { logSuccess(text: text, targetBundleID: bundleID, strategy: "C(fallback)") }
            return ok ? .injected : .leftOnClipboard(reason: L("injector.accessibility_needed"))

        case .auto:
            // Paste-only (the original, proven approach that works everywhere).
            // Target is already captured and validated; just paste reliably.
            let ok = await strategyC(text, target: target)
            if ok { logSuccess(text: text, targetBundleID: bundleID, strategy: "C") }
            return ok ? .injected : .leftOnClipboard(reason: L("injector.accessibility_needed"))
        }
    }

    // MARK: - Strategy A: Accessibility API insertion

    /// Writes directly into the focused element at the caret. No clicks, no
    /// synthetic keystrokes, no clipboard involvement — the cleanest result
    /// when the focused element supports it.
    private func strategyA(_ text: String, target: NSRunningApplication) async -> Bool {
        let systemWide = AXUIElementCreateSystemWide()

        func focusedElement() -> AXUIElement? {
            var ref: CFTypeRef?
            guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &ref) == .success,
                  let ref else { return nil }
            return (ref as! AXUIElement)
        }

        guard let element = focusedElement() else {
            logger.notice("strategyA: no system-wide focused element")
            return false
        }

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid == target.processIdentifier {
            return writeViaAX(element, text: text)
        }

        // Focused element belongs to a different process than our target.
        // Distinguish "it's us" (a Hikari Yaps window/panel is key) from
        // "some other app grabbed focus" — the former is the exact bug this
        // strategy exists to catch and recover from.
        let isSelf = pid == ProcessInfo.processInfo.processIdentifier
        let ownerBundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "pid:\(pid)"
        logger.notice("strategyA: focused element owner=\(ownerBundleID, privacy: .public) isSelf=\(isSelf, privacy: .public) target=\(target.bundleIdentifier ?? "?", privacy: .public) — retrying")
        target.activate()
        try? await Task.sleep(nanoseconds: 80_000_000)

        guard let retryElement = focusedElement() else { return false }
        var retryPid: pid_t = 0
        AXUIElementGetPid(retryElement, &retryPid)
        guard retryPid == target.processIdentifier else {
            let retryOwner = NSRunningApplication(processIdentifier: retryPid)?.bundleIdentifier ?? "pid:\(retryPid)"
            logger.notice("strategyA: retry still wrong owner=\(retryOwner, privacy: .public)")
            return false
        }
        return writeViaAX(retryElement, text: text)
    }

    private func writeViaAX(_ element: AXUIElement, text: String) -> Bool {
        // Secure fields (passwords) must never receive programmatic text —
        // belt-and-suspenders alongside the system-wide IsSecureEventInputEnabled
        // check in `inject`, since that flag can lag element-level focus.
        var subroleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
        if let subrole = subroleRef as? String, subrole == "AXSecureTextField" {
            logger.notice("strategyA: refusing secure field")
            return false
        }

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? ""
        let textCapableRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXTextView"]
        let settableSelectedText = isSettable(element, attribute: kAXSelectedTextAttribute as CFString)

        guard textCapableRoles.contains(role) || settableSelectedText else {
            logger.notice("strategyA: role=\(role, privacy: .public) not text-capable")
            return false
        }

        let success: Bool
        if settableSelectedText {
            // Preferred: replaces the current (possibly zero-length)
            // selection at the caret — exactly like typing.
            success = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
        } else {
            success = spliceIntoValue(element, text: text)
        }
        if success {
            logger.notice("strategyA: wrote via role=\(role, privacy: .public)")
        }
        return success
    }

    private func isSettable(_ element: AXUIElement, attribute: CFString) -> Bool {
        var settable: DarwinBoolean = false
        let err = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return err == .success && settable.boolValue
    }

    /// Fallback within Strategy A for elements that don't support setting
    /// `kAXSelectedTextAttribute` directly: read the value + selection range,
    /// splice the text in at the caret, write back, then move the caret to
    /// just after the inserted text.
    private func spliceIntoValue(_ element: AXUIElement, text: String) -> Bool {
        guard isSettable(element, attribute: kAXValueAttribute as CFString) else { return false }

        var valueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        let currentValue = (valueRef as? String) ?? ""
        let ns = currentValue as NSString

        var location = ns.length // default: append at the end
        var rangeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef)
        if let rangeValue = rangeRef, CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            var cfRange = CFRange()
            if AXValueGetValue((rangeValue as! AXValue), .cfRange, &cfRange) {
                location = cfRange.location
            }
        }
        let safeLocation = min(max(location, 0), ns.length)

        let newValue = ns.replacingCharacters(in: NSRange(location: safeLocation, length: 0), with: text)
        guard AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFTypeRef) == .success else {
            return false
        }

        var caretRange = CFRangeMake(safeLocation + (text as NSString).length, 0)
        if let caretValue = AXValueCreate(.cfRange, &caretRange) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue)
        }
        return true
    }

    // MARK: - Strategy B: CGEvent keystroke synthesis

    private enum TypingOutcome {
        case completed
        case partial(remaining: String)
        case failed
    }

    /// Synthesizes `text` as raw Unicode keystrokes. Aborts immediately if
    /// the frontmost app changes mid-burst — never sprays into whatever
    /// surfaced in its place — and reports the untyped remainder so the
    /// caller can paste just that portion instead.
    private func strategyB(_ text: String, target: NSRunningApplication) async -> TypingOutcome {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return .failed }
        let utf16 = Array(text.utf16)
        let chunkSize = 20
        var index = 0

        while index < utf16.count {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
                let remaining = String(decoding: utf16[index...], as: UTF16.self)
                logger.notice("strategyB: aborted mid-burst, \(remaining.count, privacy: .public) chars remaining")
                return .partial(remaining: remaining)
            }
            let chunk = Array(utf16[index..<min(index + chunkSize, utf16.count)])
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                // Strip all modifier flags — the hotkey press may have left residual
                // flags (Ctrl, Option, etc.) that browsers interpret as keyboard
                // shortcuts and silently discard. We want raw character input only.
                keyDown.flags = []
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                keyUp.flags = []
                keyUp.post(tap: .cghidEventTap)
            }
            index += chunkSize
            try? await Task.sleep(nanoseconds: 4_000_000)
        }
        return .completed
    }

    // MARK: - Strategy C: clipboard + synthesized ⌘V

    /// Puts `text` on the pasteboard, synthesizes ⌘V into `target`, then
    /// restores whatever was on the pasteboard before. Last resort — always
    /// available once Accessibility is granted and secure input isn't active.
    private func strategyC(_ text: String, target: NSRunningApplication) async -> Bool {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(of: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
            // Last-line-of-defense check right before pasting. Text stays on
            // the clipboard for the user — consistent with the leftOnClipboard
            // contract the caller returns in this case.
            logger.notice("strategyC: target no longer frontmost, leaving on clipboard")
            return false
        }

        try? await Task.sleep(nanoseconds: 60_000_000)
        synthesizeCommandV()
        try? await Task.sleep(nanoseconds: 400_000_000)
        restore(saved, to: pasteboard)
        return true
    }

    /// Synthesizes the full Cmd+V sequence: Cmd down → V down → V up → Cmd up.
    /// The V events carry the .maskCommand flag so the OS sees them as Cmd+V.
    private func synthesizeCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let cmdKey = CGKeyCode(kVK_Command)
        let vKey = CGKeyCode(kVK_ANSI_V)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false)

        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Clipboard helpers

    private func leaveOnClipboard(_ text: String, reason: String) -> InjectionResult {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return .leftOnClipboard(reason: reason)
    }

    private func snapshot(of pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        }
    }

    private func restore(_ saved: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        guard !saved.isEmpty else { return }
        pasteboard.clearContents()
        let items = saved.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    // MARK: - Logging

    private func logSuccess(text: String, targetBundleID: String, strategy: String) {
        let prefix = String(text.prefix(40))
        logger.notice("injected strategy=\(strategy, privacy: .public) target=\(targetBundleID, privacy: .public) chars=\(text.count, privacy: .public) prefix=\"\(prefix, privacy: .public)\"")
    }
}
