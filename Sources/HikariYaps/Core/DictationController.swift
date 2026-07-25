import AppKit
import SwiftUI

enum OverlayPhase: Equatable {
    case hidden
    case listening
    case transcribing
    case success(String)
    case notice(String)
    case failure(String)
}

/// Orchestrates the dictation flow:
/// hotkey → record (overlay + waveform) → transcribe → clean up → expand
/// snippets → inject → log to history → completion sound.
@MainActor
final class DictationController: ObservableObject {
    @Published private(set) var overlayPhase: OverlayPhase = .hidden {
        didSet { overlayPanel.update(for: overlayPhase) }
    }
    @Published private(set) var isRecording = false
    /// Rolling mic level history for the overlay waveform (0...1).
    @Published private(set) var levelHistory: [Float] = Array(repeating: 0, count: 36)

    private let settings: SettingsStore
    private let engine: TranscriptionEngine
    private let llmCleanup: LocalLLMCleanup
    private let permissions: PermissionsManager
    private let vocabulary: VocabularyStore
    private let snippets: SnippetStore
    private let history: HistoryStore
    private let trial: TrialManager

    private let recorder = AudioRecorder()
    private let injector = TextInjector()
    private lazy var overlayPanel = OverlayPanel(controller: self)

    private var maxDurationTimer: Timer?
    private var dismissTask: Task<Void, Never>?
    /// The transcribe → cleanup → inject pipeline for the most recent
    /// dictation. Tracked so a second dictation can't start while one is in
    /// flight (two concurrent pipelines interleave their paste sequences,
    /// clobber the clipboard, and can inject into the wrong app), and so
    /// Escape can cancel a pipeline the user no longer wants.
    private var pipelineTask: Task<Void, Never>?
    private static let maxRecordingSeconds: TimeInterval = 300

    /// The app frontmost when the hotkey was pressed — captured at the start
    /// of dictation, not the end, since that's the app the user intended to
    /// dictate into. `finishDictation` reads this rather than re-querying
    /// `NSWorkspace.shared.frontmostApplication`, which can have drifted to
    /// iVoz itself (its overlay window, or being switched back to) by the
    /// time transcription and cleanup finish.
    private var dictationTarget: NSRunningApplication?

    @MainActor
    init(settings: SettingsStore,
         engine: TranscriptionEngine,
         llmCleanup: LocalLLMCleanup,
         permissions: PermissionsManager,
         vocabulary: VocabularyStore,
         snippets: SnippetStore,
         history: HistoryStore,
         trial: TrialManager = MainActor.assumeIsolated({ TrialManager.shared })) {
        self.settings = settings
        self.engine = engine
        self.llmCleanup = llmCleanup
        self.permissions = permissions
        self.vocabulary = vocabulary
        self.snippets = snippets
        self.history = history
        self.trial = trial

        recorder.onLevel = { [weak self] level in
            guard let self else { return }
            self.levelHistory.removeFirst()
            self.levelHistory.append(level)
        }
    }

    // MARK: - Hotkey entry points

    func hotkeyHoldStarted() {
        startDictation()
    }

    func hotkeyHoldEnded(cancelled: Bool) {
        if cancelled {
            cancelDictation()
        } else {
            finishDictation()
        }
    }

    func hotkeyTapToggled() {
        if isRecording {
            finishDictation()
        } else {
            startDictation()
        }
    }

    func escapePressed() {
        if isRecording {
            cancelDictation()
        } else if pipelineTask != nil {
            // A dictation is being transcribed/cleaned/injected — cancel it so
            // nothing is injected into the target app.
            cancelPipeline()
        }
    }

    // MARK: - Flow

    func startDictation() {
        guard !isRecording else { return }
        // Refuse to start while a previous dictation is still being
        // transcribed/cleaned/injected — two concurrent pipelines interleave
        // their clipboard/paste sequences and can inject into the wrong app.
        guard pipelineTask == nil else {
            showTransient(.notice(L("dictation.busy")))
            return
        }
        dismissTask?.cancel()

        // Capture the target before any UI (overlay, permission prompts)
        // has a chance to shift frontmost-app status.
        dictationTarget = NSWorkspace.shared.frontmostApplication

        permissions.refresh()
        guard permissions.microphoneGranted else {
            showTransient(.failure(L("dictation.mic_permission_needed")))
            return
        }
        guard engine.state.isReady else {
            showTransient(.notice(engine.state.statusLabel))
            return
        }

        do {
            try recorder.start(deviceUID: settings.inputDeviceUID)
        } catch {
            showTransient(.failure(error.localizedDescription))
            return
        }

        isRecording = true
        levelHistory = Array(repeating: 0, count: levelHistory.count)
        overlayPhase = .listening

        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: Self.maxRecordingSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishDictation() }
        }
    }

    func cancelDictation() {
        guard isRecording else { return }
        isRecording = false
        maxDurationTimer?.invalidate()
        recorder.cancel()
        cancelPipeline()
        overlayPhase = .hidden
    }

    /// Cancels the in-flight transcribe → cleanup → inject pipeline, if any.
    /// Cancellation is cooperative: the pipeline checks `Task.isCancelled`
    /// between stages and before injecting text.
    private func cancelPipeline() {
        pipelineTask?.cancel()
        pipelineTask = nil
        if case .transcribing = overlayPhase {
            overlayPhase = .hidden
        }
    }

    func finishDictation() {
        guard isRecording else { return }
        isRecording = false
        maxDurationTimer?.invalidate()

        let samples = recorder.stop()
        let duration = Double(samples.count) / AudioRecorder.targetSampleRate

        // Ignore blips shorter than a spoken word.
        guard duration >= 0.4 else {
            overlayPhase = .hidden
            return
        }

        overlayPhase = .transcribing
        let target = dictationTarget
        let frontApp = target?.localizedName

        pipelineTask = Task {
            defer { pipelineTask = nil }
            do {
                let output = try await engine.transcribe(
                    samples: samples,
                    languageCode: settings.language.whisperCode,
                    vocabulary: vocabulary.words
                )
                try Task.checkCancellation()

                let pipeline = CleanupPipeline(
                    smartFormatting: settings.smartFormatting,
                    smartCleanup: settings.smartCleanup,
                    tone: settings.tone,
                    languageCode: output.language
                )
                let structured = pipeline.structure(output.text, segments: output.segments)

                var cleaned = structured
                if settings.smartCleanup {
                    // Prefer the real local LLM for filler/grammar cleanup;
                    // fall back to the deterministic regex pass if the model
                    // isn't ready yet or generation fails.
                    cleaned = await llmCleanup.cleanup(structured, tone: settings.tone)
                        ?? pipeline.regexCleanup(structured)
                }

                var text = pipeline.finish(cleaned)
                text = snippets.expand(text)

                guard !text.isEmpty else {
                    showTransient(.notice(L("dictation.no_speech_detected")))
                    return
                }

                // Suite voice commands: a transcript that starts with a suite
                // keyword routes to the target app instead of being typed.
                // Try the cleaned text first, then the raw transcript (in
                // case cleanup rephrased the keyword).
                if settings.suiteCommands,
                   let intent = SuiteIntents.match(text) ?? SuiteIntents.match(output.text) {
                    guard !Task.isCancelled else { return }
                    let feedback = SuiteActions.perform(intent)
                    history.add(text: text, rawText: output.text, duration: output.audioDuration, appName: "iSuite")
                    if settings.completionSound {
                        SoundPlayer.playCompletion()
                    }
                    showResult(.notice(feedback))
                    return
                }

                // Never inject text the user cancelled while we were working.
                guard !Task.isCancelled else {
                    overlayPhase = .hidden
                    return
                }
                let result = await injector.inject(text, method: settings.injectionMethod, target: target)
                history.add(text: text, rawText: output.text, duration: output.audioDuration, appName: frontApp)

                // Track word count for trial/subscription
                let wordCount = text.split(separator: " ").count
                trial.recordWordCount(wordCount)

                if settings.completionSound {
                    SoundPlayer.playCompletion()
                }

                switch result {
                case .injected:
                    showResult(.success(text))
                case .failed(let reason):
                    showResult(.notice(reason))
                }
            } catch is CancellationError {
                // Deliberate cancel (Escape / new-cancel path) — hide quietly.
                overlayPhase = .hidden
            } catch {
                showTransient(.failure(error.localizedDescription))
            }
        }
    }

    // MARK: - Overlay lifecycle

    private func showResult(_ phase: OverlayPhase) {
        overlayPhase = phase
        if settings.autoDismissOverlay {
            scheduleDismiss(after: 0.8)
        }
    }

    private func showTransient(_ phase: OverlayPhase) {
        overlayPhase = phase
        scheduleDismiss(after: 2.2)
    }

    func dismissOverlay() {
        dismissTask?.cancel()
        overlayPhase = .hidden
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            overlayPhase = .hidden
        }
    }
}

// MARK: - Completion sound

enum SoundPlayer {
    static func playCompletion() {
        NSSound(named: "Glass")?.play()
    }
}
