import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var engine: TranscriptionEngine
    @EnvironmentObject private var llmCleanup: LocalLLMCleanup
    @EnvironmentObject private var permissions: PermissionsManager
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var vocabulary: VocabularyStore
    @ObservedObject private var trial = TrialManager.shared

    @State private var searchQuery = ""
    @State private var quickWord = ""
    @State private var quickSnippetTrigger = ""
    @State private var quickSnippetContent = ""
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if !permissions.allGranted {
                    PermissionsCard()
                }
                heroCard
                HStack(alignment: .top, spacing: 18) {
                    smartCleanupCard
                    quickAddCard
                }
                historySection
            }
            .padding(28)
            .padding(.top, 16)
        }
        .background(Theme.windowBackground)
        .onAppear { permissions.refresh() }
        .sheet(isPresented: $trial.shouldShowLimitPopup) {
            LimitPopup(trialManager: trial)
                .frame(maxWidth: 500, maxHeight: 400)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        let stats = history.stats
        return VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day().locale(settings.uiLanguage.locale)))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                EngineStatusPill()
            }

            HStack(alignment: .top, spacing: 0) {
                StatCell(label: L("home.stat.words_today"), value: "\(stats.wordsToday)")
                    .frame(maxWidth: .infinity)
                divider
                VStack(alignment: .leading, spacing: 12) {
                    StatCell(label: L("home.stat.sessions"), value: "\(stats.sessionsToday)")
                        .frame(maxWidth: .infinity)
                    WeekBars(values: stats.weeklyWords)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                divider
                StatCell(label: L("home.stat.avg_wpm"), value: stats.averageWPM > 0 ? "\(stats.averageWPM)" : "—")
                    .frame(maxWidth: .infinity)
                divider
                StatCell(
                    label: L("home.stat.all_time"),
                    value: formatted(stats.allTimeWords),
                    detail: L("home.stat.min_saved", stats.minutesSaved)
                )
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(colors: [Theme.heroTop, Theme.heroBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .fill(Theme.gold.opacity(0.10))
                        .frame(width: 340, height: 340)
                        .blur(radius: 70)
                        .offset(x: -120, y: -120),
                    alignment: .topLeading
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(width: 1, height: 64)
            .padding(.horizontal, 22)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return L("home.greeting.morning")
        case 12..<18: return L("home.greeting.afternoon")
        default: return L("home.greeting.evening")
        }
    }

    private func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = settings.uiLanguage.locale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Quick cards

    private var smartCleanupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("ai.smart_cleanup.title"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { settings.smartCleanup },
                    set: { value in
                        settings.smartCleanup = value
                        services.smartCleanupToggled()
                    }
                ))
                .toggleStyle(GoldToggleStyle())
                .labelsHidden()
            }
            Text(L("home.smart_cleanup.subtitle"))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)

            if settings.smartCleanup, llmCleanup.state != .ready {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if case .failed = llmCleanup.state {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.danger)
                        } else {
                            ProgressView().controlSize(.mini).tint(Theme.gold)
                        }
                        Text(llmCleanup.state.statusLabel)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    if case .failed = llmCleanup.state {
                        Text(L("error.help_text"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            if case .failed = engine.state {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.danger)
                        Text(engine.state.statusLabel)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Text(L("error.help_text"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.danger.opacity(0.08))
                )
                .padding(.top, 8)
            }

            Divider().overlay(Theme.cardStroke)

            HStack {
                Text(L("ai.tone.title"))
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Picker("", selection: $settings.tone) {
                    ForEach(ToneStyle.allCases) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                Label("\(L("nav.vocabulary"))  \(vocabulary.entries.count)", systemImage: "character.book.closed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Label("\(L("nav.snippets"))  \(services.snippets.snippets.count)", systemImage: "bolt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            }

            // Vocabulary quick-add
            HStack(spacing: 10) {
                TextField(L("home.quickadd.word_placeholder"), text: $quickWord)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
                            )
                    )
                    .onSubmit(addQuickWord)
                Button(L("common.add"), action: addQuickWord)
                    .buttonStyle(PillButtonStyle(prominent: true))
            }

            // Snippet quick-add
            HStack(spacing: 10) {
                TextField(L("home.snippet.trigger_placeholder"), text: $quickSnippetTrigger)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
                            )
                    )
                TextField(L("home.snippet.content_placeholder"), text: $quickSnippetContent)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
                            )
                    )
                    .onSubmit(addQuickSnippet)
                Button(L("common.add"), action: addQuickSnippet)
                    .buttonStyle(PillButtonStyle(prominent: true))
            }

            Text(L("home.quickadd.hint"))
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func addQuickWord() {
        vocabulary.add(quickWord)
        quickWord = ""
    }

    private func addQuickSnippet() {
        services.snippets.add(trigger: quickSnippetTrigger, content: quickSnippetContent)
        quickSnippetTrigger = ""
        quickSnippetContent = ""
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Text(L("home.history.title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                    TextField(L("home.history.search_placeholder"), text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.cardStroke, lineWidth: 1)
                        )
                )

                Button {
                    confirmClear = true
                } label: {
                    Label(L("common.clear"), systemImage: "trash")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(history.entries.isEmpty)

                Button {
                    exportHistory()
                } label: {
                    Label(L("common.export"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(history.entries.isEmpty)
            }

            if history.entries.isEmpty {
                emptyHistory
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(history.grouped(query: searchQuery), id: \.day) { group in
                        daySection(group.day, entries: group.entries)
                    }
                }
            }
        }
        .confirmationDialog(L("home.history.clear_confirm_title"), isPresented: $confirmClear) {
            Button(L("home.history.clear_confirm_button"), role: .destructive) { history.clear() }
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 30))
                .foregroundStyle(Theme.textTertiary)
            Text(L("home.history.empty_hold", settings.hotkeyKey.displayName))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text(L("home.history.empty_sub"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .card()
    }

    private func daySection(_ day: Date, entries: [HistoryEntry]) -> some View {
        let words = entries.reduce(0) { $0 + $1.wordCount }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dayLabel(day).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("\(L("home.history.words_count", words)) · \(entries.count == 1 ? L("home.history.session_singular", entries.count) : L("home.history.session_plural", entries.count))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            ForEach(entries) { entry in
                HistoryRow(entry: entry)
            }
        }
        .padding(.top, 6)
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return L("common.today") }
        if calendar.isDateInYesterday(day) { return L("common.yesterday") }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(settings.uiLanguage.locale))
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .json]
        panel.nameFieldStringValue = "hikari-yaps-history.txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                if url.pathExtension.lowercased() == "json" {
                    try? history.exportJSON()?.write(to: url)
                } else {
                    try? history.exportText().data(using: .utf8)?.write(to: url)
                }
            }
        }
    }
}

// MARK: - History row

private struct HistoryRow: View {
    let entry: HistoryEntry
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var settings: SettingsStore
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.gold)
                .frame(width: 3)
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.text)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(4)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                    if let app = entry.appName {
                        Text("·")
                        Text(app)
                    }
                    Text("·")
                    Text("\(entry.wordCount) words")
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            }
            Spacer()

            HStack(spacing: 8) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(copied ? Theme.success : Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(L("common.copy_help"))

                Button {
                    history.remove(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(L("common.delete_help"))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .card()
    }
}

// MARK: - Permissions card

private struct PermissionsCard: View {
    @EnvironmentObject private var permissions: PermissionsManager
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L("permissions.title"), systemImage: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.gold)

            if !permissions.microphoneGranted {
                permissionRow(
                    icon: "mic",
                    title: L("permissions.microphone.title"),
                    detail: L("permissions.microphone.detail"),
                    action: { permissions.requestMicrophone() },
                    settingsAction: { permissions.openMicrophoneSettings() }
                )
            }
            if !permissions.accessibilityGranted {
                permissionRow(
                    icon: "accessibility",
                    title: L("permissions.accessibility.title"),
                    detail: L("permissions.accessibility.detail"),
                    action: { permissions.requestAccessibility() },
                    settingsAction: { permissions.openAccessibilitySettings() }
                )
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.gold.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func permissionRow(icon: String, title: String, detail: String,
                               action: @escaping () -> Void,
                               settingsAction: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.gold)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button(L("common.grant"), action: action)
                .buttonStyle(PillButtonStyle(prominent: true))
            Button(L("common.open_settings"), action: settingsAction)
                .buttonStyle(PillButtonStyle())
        }
    }
}
