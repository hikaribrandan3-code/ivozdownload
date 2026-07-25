import SwiftUI

// MARK: - Stat display

struct StatCell: View {
    let label: String
    let value: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .truncationMode(.tail)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Mini bar chart of words per weekday (Monday-first), Chirp-style.
struct WeekBars: View {
    let values: [Int]

    private static let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let peak = max(values.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isToday(index) ? Theme.gold : Color.white.opacity(0.18))
                        .frame(width: 22, height: max(4, CGFloat(values[index]) / CGFloat(peak) * 36))
                    Text(Self.labels[index])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isToday(index) ? Theme.gold : Theme.textTertiary)
                }
            }
        }
    }

    private func isToday(_ index: Int) -> Bool {
        // Convert Sunday-first weekday to Monday-first index.
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7 == index
    }
}

// MARK: - Settings rows

struct SettingsRow<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct GoldToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Theme.gold : Color.white.opacity(0.12))
                    .frame(width: 44, height: 26)
                Circle()
                    .fill(configuration.isOn ? Theme.card : Color.white.opacity(0.85))
                    .frame(width: 20, height: 20)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Buttons

struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        let mode = UserDefaults.standard.string(forKey: "themeMode") ?? "dark"
        let isLight = mode == "light"

        return configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(
                prominent
                    ? (isLight ? Color.white : Color(hex: 0x1C1509))
                    : Theme.textPrimary
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    prominent
                        ? Theme.gold
                        : (isLight ? Color(hex: 0xF0F0F0) : Color.white.opacity(0.08))
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    prominent ? .clear : (isLight ? Color(hex: 0xE0E0E0) : Theme.cardStroke),
                    lineWidth: 1
                )
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Level meter

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.goldDim, Theme.gold, Theme.goldSoft],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, proxy.size.width * CGFloat(min(level, 1))))
                    .animation(.linear(duration: 0.08), value: level)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Status pill

struct EngineStatusPill: View {
    @EnvironmentObject private var engine: TranscriptionEngine

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(engine.state.statusLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textPrimary.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private var color: Color {
        switch engine.state {
        case .ready: return Theme.success
        case .failed: return Theme.danger
        default: return Theme.gold
        }
    }
}
