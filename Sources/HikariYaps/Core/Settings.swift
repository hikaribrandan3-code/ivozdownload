import Foundation
import AppKit
import ServiceManagement

// MARK: - Setting enums

enum HotkeyKey: String, CaseIterable, Identifiable {
    case control
    case option
    case rightCommand
    case function

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .control: return "Ctrl"
        case .option: return "Option"
        case .rightCommand: return "R-Cmd"
        case .function: return "Fn"
        }
    }

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .rightCommand: return "⌘"
        case .function: return "🌐"
        }
    }

    /// Key codes that identify this modifier in flagsChanged events.
    var keyCodes: Set<UInt16> {
        switch self {
        case .control: return [59, 62]        // left / right control
        case .option: return [58, 61]         // left / right option
        case .rightCommand: return [54]       // right command only
        case .function: return [63]           // fn / globe
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option: return .option
        case .rightCommand: return .command
        case .function: return .function
        }
    }

    static func from(keyCode: UInt16) -> HotkeyKey? {
        allCases.first { $0.keyCodes.contains(keyCode) }
    }
}

enum HotkeyBehavior: String, CaseIterable, Identifiable {
    case hold
    case tap

    var id: String { rawValue }
    @MainActor var displayName: String { self == .hold ? L("hotkey.behavior.hold") : L("hotkey.behavior.tap") }
}

enum ToneStyle: String, CaseIterable, Identifiable {
    case message
    case professional
    case concise
    case code

    var id: String { rawValue }

    @MainActor var displayName: String {
        switch self {
        case .message: return L("tone.message")
        case .professional: return L("tone.professional")
        case .concise: return L("tone.concise")
        case .code: return L("tone.code")
        }
    }

    @MainActor var blurb: String {
        switch self {
        case .message: return L("tone.blurb.message")
        case .professional: return L("tone.blurb.professional")
        case .concise: return L("tone.blurb.concise")
        case .code: return L("tone.blurb.code")
        }
    }
}

enum InjectionMethod: String, CaseIterable, Identifiable {
    /// Tries Accessibility insertion, then keystroke simulation, then
    /// clipboard paste — whichever works first. Best default for new users.
    case auto
    case paste
    case type

    var id: String { rawValue }

    @MainActor var displayName: String {
        switch self {
        case .auto: return L("injection.auto")
        case .paste: return L("injection.paste")
        case .type: return L("injection.type")
        }
    }
}

enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case auto, en, es, pt, fr, de, it, ja, ko, zh

    var id: String { rawValue }

    /// Every language name shown in its own language — the standard for
    /// language pickers — except "Auto-detect" which follows the UI language.
    @MainActor var displayName: String {
        switch self {
        case .auto: return L("language.auto_detect")
        case .en: return "English"
        case .es: return "Español"
        case .pt: return "Português"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zh: return "中文"
        }
    }

    /// Whisper language code, nil means auto-detect.
    var whisperCode: String? { self == .auto ? nil : rawValue }
}

struct WhisperModelOption: Identifiable, Hashable {
    let variant: String
    let displayName: String
    let detail: String

    var id: String { variant }

    static let standardChoices: [WhisperModelOption] = [
        .init(variant: "openai_whisper-tiny", displayName: "Tiny", detail: "~75 MB · fastest"),
        .init(variant: "openai_whisper-base", displayName: "Base", detail: "~145 MB · fast, good accuracy"),
        .init(variant: "openai_whisper-small", displayName: "Small", detail: "~480 MB · slower, better accuracy"),
    ]

    static let enhancedChoices: [WhisperModelOption] = [
        .init(variant: "openai_whisper-small", displayName: "Small", detail: "~480 MB · balanced"),
        .init(variant: "openai_whisper-large-v3-v20240930_turbo_632MB", displayName: "Large v3 Turbo (compressed)", detail: "~630 MB · near-best accuracy"),
        .init(variant: "openai_whisper-large-v3-v20240930_turbo", displayName: "Large v3 Turbo", detail: "~1.6 GB · best accuracy"),
    ]
}

// MARK: - Settings store

/// Central user settings, persisted to UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    @Published var hotkeyKey: HotkeyKey { didSet { defaults.set(hotkeyKey.rawValue, forKey: "hotkeyKey") } }
    @Published var hotkeyBehavior: HotkeyBehavior { didSet { defaults.set(hotkeyBehavior.rawValue, forKey: "hotkeyBehavior") } }
    @Published var inputDeviceUID: String { didSet { defaults.set(inputDeviceUID, forKey: "inputDeviceUID") } }
    @Published var smartFormatting: Bool { didSet { defaults.set(smartFormatting, forKey: "smartFormatting") } }
    @Published var smartCleanup: Bool { didSet { defaults.set(smartCleanup, forKey: "smartCleanup") } }
    @Published var tone: ToneStyle { didSet { defaults.set(tone.rawValue, forKey: "tone") } }
    @Published var enhancedRecognition: Bool { didSet { defaults.set(enhancedRecognition, forKey: "enhancedRecognition") } }
    @Published var standardModel: String { didSet { defaults.set(standardModel, forKey: "standardModel") } }
    @Published var enhancedModel: String { didSet { defaults.set(enhancedModel, forKey: "enhancedModel") } }
    @Published var language: TranscriptionLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
    @Published var uiLanguage: AppLanguage { didSet { defaults.set(uiLanguage.rawValue, forKey: "uiLanguage") } }
    @Published var autoDismissOverlay: Bool { didSet { defaults.set(autoDismissOverlay, forKey: "autoDismissOverlay") } }
    @Published var completionSound: Bool { didSet { defaults.set(completionSound, forKey: "completionSound") } }
    @Published var injectionMethod: InjectionMethod { didSet { defaults.set(injectionMethod.rawValue, forKey: "injectionMethod") } }
    @Published var suiteCommands: Bool { didSet { defaults.set(suiteCommands, forKey: "suiteCommands") } }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }

    /// The model variant that should be active given the Enhanced Recognition toggle.
    var activeModelVariant: String { enhancedRecognition ? enhancedModel : standardModel }

    private init() {
        hotkeyKey = HotkeyKey(rawValue: defaults.string(forKey: "hotkeyKey") ?? "") ?? .control
        hotkeyBehavior = HotkeyBehavior(rawValue: defaults.string(forKey: "hotkeyBehavior") ?? "") ?? .hold
        inputDeviceUID = defaults.string(forKey: "inputDeviceUID") ?? ""
        smartFormatting = defaults.object(forKey: "smartFormatting") as? Bool ?? true
        smartCleanup = defaults.object(forKey: "smartCleanup") as? Bool ?? true
        tone = ToneStyle(rawValue: defaults.string(forKey: "tone") ?? "") ?? .message
        enhancedRecognition = defaults.object(forKey: "enhancedRecognition") as? Bool ?? false
        standardModel = defaults.string(forKey: "standardModel") ?? "openai_whisper-base"
        enhancedModel = defaults.string(forKey: "enhancedModel") ?? "openai_whisper-large-v3-v20240930_turbo_632MB"
        language = TranscriptionLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .auto
        // Default Spanish, neutral — no region-specific slang.
        uiLanguage = AppLanguage(rawValue: defaults.string(forKey: "uiLanguage") ?? "") ?? .es
        autoDismissOverlay = defaults.object(forKey: "autoDismissOverlay") as? Bool ?? true
        completionSound = defaults.object(forKey: "completionSound") as? Bool ?? true
        injectionMethod = InjectionMethod(rawValue: defaults.string(forKey: "injectionMethod") ?? "") ?? .auto
        suiteCommands = defaults.object(forKey: "suiteCommands") as? Bool ?? true
        launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
    }

    private func applyLaunchAtLogin() {
        // SMAppService only works from a real .app bundle; ignore failures when
        // running unbundled during development.
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login change failed: \(error.localizedDescription)")
        }
    }
}
