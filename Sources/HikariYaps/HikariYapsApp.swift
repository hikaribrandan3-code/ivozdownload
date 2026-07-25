import SwiftUI
import AppKit

/// Composition root: builds and wires every service exactly once.
@MainActor
final class AppServices: ObservableObject {
    static let shared = AppServices()

    let settings: SettingsStore
    let permissions: PermissionsManager
    let engine: TranscriptionEngine
    let llmCleanup: LocalLLMCleanup
    let vocabulary: VocabularyStore
    let snippets: SnippetStore
    let history: HistoryStore
    let dictation: DictationController
    let hotkeys: HotkeyManager
    let trial: TrialManager
    let devices = AudioDeviceManager.shared

    private var started = false

    private init() {
        let settings = SettingsStore.shared
        self.settings = settings
        permissions = PermissionsManager()
        engine = TranscriptionEngine()
        llmCleanup = LocalLLMCleanup()
        vocabulary = VocabularyStore()
        snippets = SnippetStore()
        history = HistoryStore()
        trial = TrialManager.shared
        dictation = DictationController(
            settings: settings,
            engine: engine,
            llmCleanup: llmCleanup,
            permissions: permissions,
            vocabulary: vocabulary,
            snippets: snippets,
            history: history
        )
        hotkeys = HotkeyManager(settings: settings)

        hotkeys.onHoldStart = { [weak self] in self?.dictation.hotkeyHoldStarted() }
        hotkeys.onHoldEnd = { [weak self] cancelled in self?.dictation.hotkeyHoldEnded(cancelled: cancelled) }
        hotkeys.onTapToggle = { [weak self] in self?.dictation.hotkeyTapToggled() }
        hotkeys.onEscape = { [weak self] in self?.dictation.escapePressed() }
        hotkeys.onCaptured = { [weak self] key in self?.settings.hotkeyKey = key }
    }

    func start() {
        guard !started else { return }
        started = true
        permissions.refresh()
        hotkeys.start()
        engine.activate(variant: settings.activeModelVariant)
        if settings.smartCleanup {
            llmCleanup.activate()
        }
    }

    /// Reloads the model when the Enhanced Recognition toggle or model
    /// selection changes.
    func modelSelectionChanged() {
        engine.activate(variant: settings.activeModelVariant)
    }

    /// Kicks off the cleanup model's download/load the first time Smart
    /// Cleanup is turned on.
    func smartCleanupToggled() {
        if settings.smartCleanup {
            llmCleanup.activate()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Single-instance check: if another instance is running, bring it to foreground and exit
        if let existingApp = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existingApp.activate(options: .activateAllWindows)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.terminate(nil)
            }
            return
        }

        Task { @MainActor in
            AppServices.shared.start()
        }

        // Window sizing: let macOS handle it naturally for proper fullscreen/maximize behavior.
        // The window controller already has sensible defaults (1120x740).
        // This approach matches Apple's HIG and lets users fullscreen without content clipping.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("main") ?? false }) {
                mainWindow.isRestorable = true
                mainWindow.restorationClass = nil
            }
        }

        // Launched at login by the suite LaunchAgent: stay in the menu bar,
        // no window pops. Hotkey + overlay work as usual.
        if CommandLine.arguments.contains("--background") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.windows.forEach { $0.orderOut(nil) }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the hotkey + overlay alive with the window closed.
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Always bring main window to front, whether it's visible or not
        if let mainWindow = sender.windows.first(where: { $0.identifier?.rawValue.contains("main") ?? false }) {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
            sender.activate(ignoringOtherApps: true)
        }
        return true
    }
}

@main
struct HikariYapsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices.shared
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        Window("iVoz", id: "main") {
            MainWindowView()
                .environmentObject(services)
                .environmentObject(services.settings)
                .environmentObject(services.engine)
                .environmentObject(services.llmCleanup)
                .environmentObject(services.permissions)
                .environmentObject(services.vocabulary)
                .environmentObject(services.snippets)
                .environmentObject(services.history)
                .environmentObject(services.dictation)
                .environmentObject(services.hotkeys)
                .environmentObject(services.devices)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.mode == .dark ? .dark : .light)
                .frame(minWidth: 980, minHeight: 660)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1120, height: 740)

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(services)
                .environmentObject(services.settings)
                .environmentObject(services.engine)
        } label: {
            Image(systemName: "waveform")
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var engine: TranscriptionEngine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(engine.state.statusLabel)
        Divider()
        Button(L("menubar.open")) {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        .keyboardShortcut("o")

        Picker(L("settings.hotkey_behavior.title"), selection: $settings.hotkeyBehavior) {
            ForEach(HotkeyBehavior.allCases) { behavior in
                Text(behavior.displayName).tag(behavior)
            }
        }
        Toggle(L("settings.enhanced_recognition.title"), isOn: Binding(
            get: { settings.enhancedRecognition },
            set: { value in
                settings.enhancedRecognition = value
                services.modelSelectionChanged()
            }
        ))
        Divider()
        Button(L("menubar.quit")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
