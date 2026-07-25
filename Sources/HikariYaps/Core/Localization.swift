import Foundation

/// UI display language — independent from `TranscriptionLanguage` (the
/// language Whisper listens for). Neutral Spanish, US English, Brazilian
/// Portuguese.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case es, en, pt

    var id: String { rawValue }

    /// Always shown in its own language, like every language picker on macOS.
    var nativeName: String {
        switch self {
        case .es: return "Español"
        case .en: return "English"
        case .pt: return "Português"
        }
    }

    var locale: Locale {
        switch self {
        case .es: return Locale(identifier: "es_ES")
        case .en: return Locale(identifier: "en_US")
        case .pt: return Locale(identifier: "pt_BR")
        }
    }
}

/// Every user-facing string in the app should route through `L(_:)` instead
/// of being hardcoded, so the whole UI can switch language instantly. Views
/// that read `settings.uiLanguage` (directly or via any other `@Published`
/// property on the same `SettingsStore`) re-render automatically when the
/// language changes, since they hold it as an `@EnvironmentObject`.
@MainActor
func L(_ key: String) -> String {
    guard let row = Strings.table[key] else { return key }
    return row[SettingsStore.shared.uiLanguage] ?? row[.en] ?? key
}

/// `String(format:)` convenience for keys with `%d` / `%@` placeholders.
@MainActor
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
