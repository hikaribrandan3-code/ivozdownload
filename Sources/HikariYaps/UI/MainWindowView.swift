import SwiftUI

enum NavSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case vocabulary = "Vocabulary"
    case snippets = "Snippets"
    case suiteCommands = "Suite Commands"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .vocabulary: return "character.book.closed"
        case .snippets: return "bolt"
        case .suiteCommands: return "waveform.circle.fill"
        case .settings: return "gearshape"
        }
    }

    @MainActor var displayName: String {
        switch self {
        case .home: return L("nav.home")
        case .vocabulary: return L("nav.vocabulary")
        case .snippets: return L("nav.snippets")
        case .suiteCommands: return L("nav.suite_commands")
        case .settings: return L("nav.settings")
        }
    }
}

struct MainWindowView: View {
    @State private var selection: NavSection = .home
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection)
            Group {
                switch selection {
                case .home: HomeView()
                case .vocabulary: VocabularyView()
                case .snippets: SnippetsView()
                case .suiteCommands: SuiteCommandsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.windowBackground)
        }
        .ignoresSafeArea(edges: .bottom)
        .transaction { transaction in
            transaction.animation = .easeInOut(duration: 0.2)
        }
        .id(themeManager.mode)
    }
}

struct SidebarView: View {
    @Binding var selection: NavSection
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var showUpdateSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Brand - Click to toggle light/dark theme (hidden feature)
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    themeManager.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.gold.opacity(0.16))
                            .frame(width: 34, height: 34)
                        Image(systemName: "waveform")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    Text("iVoz")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .contentShape(Rectangle())
            .help("Click to toggle light/dark mode")

            ForEach([NavSection.home, .vocabulary, .snippets, .suiteCommands]) { section in
                navButton(section)
            }

            Button {
                showUpdateSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 22)
                    Text(L("nav.update"))
                        .font(.system(size: 14, weight: .regular))
                    Spacer()
                }
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .sheet(isPresented: $showUpdateSheet) {
                UpdateSheet()
            }

            navButton(.settings)

            Spacer()
        }
        .frame(width: 230)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.sidebarBackground)
    }

    private func navButton(_ section: NavSection) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                Text(section.displayName)
                    .font(.system(size: 14, weight: selection == section ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(selection == section ? Theme.gold : Theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selection == section ? Theme.gold.opacity(0.1) : .clear)
            )
            .overlay(alignment: .leading) {
                if selection == section {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.gold)
                        .frame(width: 3, height: 22)
                        .offset(x: -1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }
}
