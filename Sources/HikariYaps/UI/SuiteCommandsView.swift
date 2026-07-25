import SwiftUI

struct SuiteCommandsView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                commandsSection
            }
            .padding(28)
            .padding(.top, 16)
            .padding(.bottom, 80)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .background(Theme.windowBackground)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("nav.suite_commands"))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(L("settings.suite_commands.subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(3)
        }
    }

    private var commandsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(SuiteCommandReference.all, id: \.titleKey) { cmd in
                commandCard(cmd)
            }
        }
    }

    private func commandCard(_ cmd: SuiteCommandReference) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: cmd.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 24)
                Text(L(cmd.titleKey))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(examplesForCommand(cmd), id: \.self) { example in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(Theme.textSecondary)
                            .font(.system(size: 12, weight: .semibold))
                        Text(example)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardStroke, lineWidth: 1)
        )
    }

    private func examplesForCommand(_ cmd: SuiteCommandReference) -> [String] {
        switch settings.uiLanguage {
        case .es: return [cmd.exampleES]
        case .en: return [cmd.exampleEN]
        case .pt: return [cmd.examplePT]
        }
    }
}
