import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var engine: TranscriptionEngine
    @EnvironmentObject private var llmCleanup: LocalLLMCleanup
    @EnvironmentObject private var hotkeys: HotkeyManager
    @EnvironmentObject private var devices: AudioDeviceManager
    @EnvironmentObject private var dictation: DictationController
    @ObservedObject private var license = LicenseManager.shared
    @ObservedObject private var trial = TrialManager.shared

    @State private var testLevel: Float = 0
    @State private var isTestingMic = false
    @State private var licenseCode = ""
    // Must be a @StateObject: a plain property on a View struct is
    // re-instantiated every time SwiftUI rebuilds the view, so stopMicTest()
    // used to call cancel() on a *fresh* recorder while the original engine
    // kept recording forever (live-mic leak).
    @StateObject private var micTest = MicTestRecorder()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                licenseSection
                languageSection
                hotkeySection
                audioSection
                aiSection
                behaviorSection

                Text("iVoz v1.0.0")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .padding(28)
            .padding(.top, 16)
            .padding(.bottom, 80)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .background(Theme.windowBackground)
        .onDisappear { stopMicTest() }
    }

    // MARK: - License

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(L("settings.section.license"))
            VStack(spacing: 0) {
                SettingsRow(title: L("license.status_title"), subtitle: licenseStatusSubtitle) {
                    if license.isActivated {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                            Text(L("license.status_pro"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }

                if !license.isActivated {
                    Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                    HStack(spacing: 10) {
                        Link(destination: URL(string: "https://ivoz.vercel.app")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(L("license.upgrade_button"))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Theme.gold)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                    HStack(spacing: 10) {
                        TextField(L("license.code_placeholder"), text: $licenseCode)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .frame(width: 200)
                            .onSubmit(activateLicense)

                        Button(L("license.activate_button")) {
                            activateLicense()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                        .disabled(license.isRedeeming)

                        if license.isRedeeming {
                            ProgressView().controlSize(.small)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    if let error = license.redeemError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                    }
                }
            }
            .card()
        }
    }

    private var licenseStatusSubtitle: String {
        if license.isActivated {
            return L("license.status_pro_subtitle")
        } else if trial.isTrialActive {
            return L("license.status_trial_subtitle_format", trial.trialDaysRemaining)
        } else {
            return L("license.status_expired_subtitle_format", trial.wordCount, trial.monthlyLimit)
        }
    }

    private func activateLicense() {
        Task {
            await license.redeem(code: licenseCode)
            if license.isActivated {
                licenseCode = ""
            }
        }
    }

    // MARK: - Language

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(L("settings.section.language"))
            VStack(spacing: 0) {
                SettingsRow(title: L("settings.section.language"), subtitle: L("settings.ui_language.subtitle")) {
                    Picker("", selection: $settings.uiLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.nativeName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
            }
            .card()
        }
    }

    // MARK: - Hotkey

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(L("settings.section.hotkey"))
            VStack(spacing: 0) {
                SettingsRow(
                    title: L("settings.hotkey.title"),
                    subtitle: settings.hotkeyBehavior == .hold ? L("settings.hotkey.subtitle_hold") : L("settings.hotkey.subtitle_tap")
                ) {
                    HStack(spacing: 12) {
                        Text(hotkeys.isCapturing ? L("settings.hotkey.press_modifier") : settings.hotkeyKey.displayName)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(hotkeys.isCapturing ? Theme.gold : Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(hotkeys.isCapturing ? Theme.gold.opacity(0.6) : .clear, lineWidth: 1)
                                    )
                            )
                        Button(hotkeys.isCapturing ? L("common.cancel") : L("common.change")) {
                            if hotkeys.isCapturing {
                                hotkeys.cancelCapture()
                            } else {
                                hotkeys.beginCapture()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                    }
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                SettingsRow(
                    title: L("settings.hotkey_behavior.title"),
                    subtitle: settings.hotkeyBehavior == .hold ? L("settings.hotkey_behavior.subtitle_hold") : L("settings.hotkey_behavior.subtitle_tap")
                ) {
                    Picker("", selection: $settings.hotkeyBehavior) {
                        ForEach(HotkeyBehavior.allCases) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }
            }
            .card()
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(L("settings.section.audio"))
            VStack(spacing: 0) {
                SettingsRow(title: L("settings.input_device.title"), subtitle: L("settings.input_device.subtitle")) {
                    Picker("", selection: $settings.inputDeviceUID) {
                        Text(L("common.default")).tag("")
                        ForEach(devices.inputDevices) { device in
                            Text(device.name).tag(device.uid)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text(L("settings.input_level.title"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Button(isTestingMic ? L("common.stop") : L("settings.input_level.test_button")) {
                            isTestingMic ? stopMicTest() : startMicTest()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                        Spacer()
                    }
                    LevelMeter(level: testLevel)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .card()
        }
    }

    private func startMicTest() {
        guard !dictation.isRecording else { return }
        micTest.recorder.onLevel = { level in
            testLevel = level
        }
        do {
            try micTest.recorder.start(deviceUID: settings.inputDeviceUID)
            isTestingMic = true
        } catch {
            testLevel = 0
        }
    }

    private func stopMicTest() {
        guard isTestingMic || micTest.recorder.isRecording else { return }
        micTest.recorder.cancel()
        isTestingMic = false
        testLevel = 0
    }

    // MARK: - AI & Output

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(L("settings.section.ai"))
            VStack(spacing: 0) {
                SettingsRow(title: L("settings.smart_formatting.title"), subtitle: L("settings.smart_formatting.subtitle")) {
                    Toggle("", isOn: $settings.smartFormatting)
                        .toggleStyle(GoldToggleStyle())
                        .labelsHidden()
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                SettingsRow(title: L("ai.smart_cleanup.title"), subtitle: cleanupSubtitle) {
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
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                SettingsRow(title: L("ai.tone.title"), subtitle: settings.tone.blurb) {
                    Picker("", selection: $settings.tone) {
                        ForEach(ToneStyle.allCases) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                SettingsRow(title: L("settings.enhanced_recognition.title"), subtitle: L("settings.enhanced_recognition.subtitle")) {
                    Toggle("", isOn: Binding(
                        get: { settings.enhancedRecognition },
                        set: { value in
                            settings.enhancedRecognition = value
                            services.modelSelectionChanged()
                        }
                    ))
                    .toggleStyle(GoldToggleStyle())
                    .labelsHidden()
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                SettingsRow(title: L("settings.dictation_language.title"), subtitle: L("settings.dictation_language.subtitle")) {
                    Picker("", selection: $settings.language) {
                        ForEach(TranscriptionLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                modelRow(
                    title: L("settings.standard_model.title"),
                    subtitle: L("settings.standard_model.subtitle"),
                    choices: WhisperModelOption.standardChoices,
                    selection: $settings.standardModel
                )
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                modelRow(
                    title: L("settings.enhanced_model.title"),
                    subtitle: L("settings.enhanced_model.subtitle"),
                    choices: WhisperModelOption.enhancedChoices,
                    selection: $settings.enhancedModel
                )
            }
            .card()
        }
    }

    private var cleanupSubtitle: String {
        guard settings.smartCleanup else { return L("settings.smart_cleanup.subtitle_off") }
        switch llmCleanup.state {
        case .ready: return L("settings.smart_cleanup.subtitle_ready")
        case .failed: return L("settings.smart_cleanup.subtitle_failed")
        default: return llmCleanup.state.statusLabel
        }
    }

    private func modelRow(title: String, subtitle: String, choices: [WhisperModelOption], selection: Binding<String>) -> some View {
        SettingsRow(title: title, subtitle: subtitle) {
            HStack(spacing: 10) {
                if engine.downloadedVariants.contains(selection.wrappedValue) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.success)
                        .help(L("settings.model.downloaded_help"))
                }
                Picker("", selection: selection) {
                    ForEach(choices) { option in
                        Text("\(option.displayName) — \(option.detail)").tag(option.variant)
                    }
                }
                .labelsHidden()
                .frame(width: 300)
                .onChange(of: selection.wrappedValue) {
                    services.modelSelectionChanged()
                }
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(L("settings.section.behavior"))
            VStack(spacing: 0) {
                SettingsRow(title: L("settings.launch_at_login.title"), subtitle: L("settings.launch_at_login.subtitle")) {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .toggleStyle(GoldToggleStyle())
                        .labelsHidden()
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                SettingsRow(title: L("settings.auto_dismiss.title"), subtitle: L("settings.auto_dismiss.subtitle")) {
                    Toggle("", isOn: $settings.autoDismissOverlay)
                        .toggleStyle(GoldToggleStyle())
                        .labelsHidden()
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                SettingsRow(title: L("settings.completion_sound.title"), subtitle: L("settings.completion_sound.subtitle")) {
                    Toggle("", isOn: $settings.completionSound)
                        .toggleStyle(GoldToggleStyle())
                        .labelsHidden()
                }
                Divider().overlay(Theme.cardStroke).padding(.horizontal, 20)
                SettingsRow(title: L("settings.injection_method.title"), subtitle: L("settings.injection_method.subtitle")) {
                    Picker("", selection: $settings.injectionMethod) {
                        ForEach(InjectionMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)
                }
            }
            .card()
        }
    }
}


/// Owns the mic-test recorder as a stable reference across SwiftUI view
/// re-creation. A plain property on the View struct is re-instantiated on
/// every rebuild, which leaked a running AVAudioEngine (live-mic leak) —
/// @StateObject keeps a single instance for the view's lifetime.
@MainActor
private final class MicTestRecorder: ObservableObject {
    let recorder = AudioRecorder()
}
