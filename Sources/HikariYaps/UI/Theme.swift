import SwiftUI

enum ThemeMode: String, Codable {
    case dark
    case light
}

/// Theme manager — handles dark/light mode switching.
@MainActor
final class ThemeManager: ObservableObject {
    @Published var mode: ThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        self.mode = ThemeMode(rawValue: saved) ?? .dark
    }

    func toggle() {
        withAnimation(.easeInOut(duration: 0.25)) {
            mode = mode == .dark ? .light : .dark
        }
    }
}

/// Neutral theme with Apple glasmorphism — adapts to light/dark mode.
enum Theme {
    static var windowBackground: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0xF5F5F5) : Color(hex: 0x0A0A0A)
    }

    static var sidebarBackground: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0xFFFFFF) : Color(hex: 0x1C1C1E)
    }

    static var card: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0xF9F9F9) : Color(hex: 0x2C2C2E)
    }

    static var cardElevated: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0xFFFFFF) : Color(hex: 0x3A3A3C)
    }

    static var heroTop: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0xFFFFFF) : Color(hex: 0x1C1C1E)
    }

    static var heroBottom: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0xF5F5F5) : Color(hex: 0x0A0A0A)
    }

    // Accent - Pure blue (same in both modes)
    static let gold = Color(hex: 0x0071E3)
    static let goldSoft = Color(hex: 0x3D94FF)
    static let goldDim = Color(hex: 0x0055B8)

    // Text - Inverts between dark/light
    static var textPrimary: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0x000000) : Color(hex: 0xFFFFFF)
    }

    static var textSecondary: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0x666666) : Color(hex: 0xA1A1A6)
    }

    static var textTertiary: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color(hex: 0x999999) : Color(hex: 0x6E6E73)
    }

    // Semantic (same in both modes)
    static let success = Color(hex: 0x4CC38A)
    static let danger = Color(hex: 0xE5533F)

    static var cardStroke: Color {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        return mode == "light" ? Color.black.opacity(0.06) : Color.white.opacity(0.06)
    }

    static let cornerRadius: CGFloat = 20
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Shared modifiers

struct CardBackground: ViewModifier {
    var elevated = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(elevated ? Theme.cardElevated : Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func card(elevated: Bool = false) -> some View {
        modifier(CardBackground(elevated: elevated))
    }
}

struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.textTertiary)
    }
}
