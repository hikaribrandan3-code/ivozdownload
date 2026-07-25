import AppKit
import AVFoundation
import ApplicationServices

/// Tracks the two permissions Hikari Yaps needs: Microphone (capture) and
/// Accessibility (global hotkey + text injection).
@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var microphoneGranted = false
    @Published private(set) var accessibilityGranted = false

    var allGranted: Bool { microphoneGranted && accessibilityGranted }

    private var pollTimer: Timer?

    init() {
        refresh()
    }

    func refresh() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startPollingUntilGranted()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        startPollingUntilGranted()
    }

    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
        startPollingUntilGranted()
    }

    /// Accessibility grants don't notify the app, so poll briefly after
    /// sending the user to System Settings.
    private func startPollingUntilGranted() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                self.refresh()
                if self.allGranted {
                    timer.invalidate()
                    self.pollTimer = nil
                }
            }
        }
    }
}
