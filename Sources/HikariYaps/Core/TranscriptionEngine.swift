import Foundation
import WhisperKit

enum EngineState: Equatable {
    case unloaded
    case downloading(progress: Double)
    case loading
    case ready
    case transcribing
    case failed(String)

    var isReady: Bool { self == .ready }

    @MainActor var statusLabel: String {
        switch self {
        case .unloaded: return L("engine.status.idle")
        case .downloading(let p): return L("engine.status.downloading", Int(p * 100))
        case .loading: return L("engine.status.loading")
        case .ready: return L("common.ready")
        case .transcribing: return L("engine.status.transcribing")
        case .failed: return L("engine.status.error")
        }
    }
}

struct TranscriptionOutput {
    let text: String
    let segments: [(text: String, start: Double, end: Double)]
    let language: String
    let audioDuration: TimeInterval
}

/// Wraps WhisperKit: model download, load lifecycle, and transcription.
/// Whisper's encoder runs on the Neural Engine via Core ML.
@MainActor
final class TranscriptionEngine: ObservableObject {
    @Published private(set) var state: EngineState = .unloaded
    @Published private(set) var loadedVariant: String?
    @Published private(set) var downloadedVariants: Set<String> = []

    private var whisperKit: WhisperKit?
    private var loadTask: Task<Void, Never>?

    /// Models live in Application Support so they survive app updates.
    static var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HikariYaps", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    init() {
        refreshDownloadedVariants()
    }

    func refreshDownloadedVariants() {
        // WhisperKit snapshots land under <base>/models/<repo>/<variant>.
        let repoDir = Self.modelsDirectory
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: repoDir.path)) ?? []
        downloadedVariants = Set(names.filter { !$0.hasPrefix(".") })
    }

    /// Downloads (if needed) and loads the given model variant.
    func activate(variant: String) {
        let busyWithSameVariant = loadedVariant == variant &&
            (state.isReady || state == .loading || state == .transcribing)
        guard !busyWithSameVariant else { return }
        loadTask?.cancel()
        loadTask = Task { await self.loadModel(variant: variant) }
    }

    /// Local folder for a variant under WhisperKit's repo layout, if already downloaded.
    private func localModelFolder(for variant: String) -> URL? {
        let folder = Self.modelsDirectory
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(variant, isDirectory: true)
        return FileManager.default.fileExists(atPath: folder.path) ? folder : nil
    }

    private func loadModel(variant: String) async {
        do {
            let folder: URL
            if let cached = localModelFolder(for: variant) {
                // Already on disk — load directly, no Hub API call. Keeps cold
                // boot working offline instead of racing the Wi-Fi reconnect.
                state = .loading
                folder = cached
            } else {
                state = .downloading(progress: 0)
                folder = try await WhisperKit.download(
                    variant: variant,
                    downloadBase: Self.modelsDirectory,
                    useBackgroundSession: false
                ) { progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.loadedVariant != variant else { return }
                        if case .downloading = self.state {
                            self.state = .downloading(progress: progress.fractionCompleted)
                        }
                    }
                }
                if Task.isCancelled { return }
                refreshDownloadedVariants()
                state = .loading
            }

            let config = WhisperKitConfig(
                modelFolder: folder.path,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )
            let kit = try await WhisperKit(config)
            if Task.isCancelled { return }
            whisperKit = kit
            loadedVariant = variant
            state = .ready
        } catch {
            if Task.isCancelled { return }
            state = .failed(error.localizedDescription)
        }
    }

    /// Transcribes 16 kHz mono samples. `vocabulary` biases decoding toward
    /// custom words via Whisper's prompt-conditioning.
    func transcribe(samples: [Float], languageCode: String?, vocabulary: [String]) async throws -> TranscriptionOutput {
        guard let kit = whisperKit, state.isReady else {
            throw NSError(domain: "HikariYaps", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "Speech model is not ready yet."
            ])
        }

        state = .transcribing
        defer { state = .ready }

        var options = DecodingOptions()
        options.task = .transcribe
        options.language = languageCode
        options.usePrefillPrompt = languageCode != nil
        options.detectLanguage = languageCode == nil
        options.skipSpecialTokens = true
        options.chunkingStrategy = .vad

        if !vocabulary.isEmpty, let tokenizer = kit.tokenizer {
            let glossary = " " + vocabulary.joined(separator: ", ") + "."
            let tokens = tokenizer.encode(text: glossary)
                .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            if !tokens.isEmpty {
                options.promptTokens = Array(tokens.suffix(180))
            }
        }

        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)

        let text = results.map { $0.text }.joined(separator: " ")
        let segments = results.flatMap { result in
            result.segments.map { (text: $0.text, start: Double($0.start), end: Double($0.end)) }
        }
        let language = results.first?.language ?? (languageCode ?? "en")
        let duration = Double(samples.count) / AudioRecorder.targetSampleRate

        return TranscriptionOutput(text: text, segments: segments, language: language, audioDuration: duration)
    }

    /// Deletes a downloaded model from disk.
    func deleteModel(variant: String) {
        let dir = Self.modelsDirectory
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(variant, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        if loadedVariant == variant {
            whisperKit = nil
            loadedVariant = nil
            state = .unloaded
        }
        refreshDownloadedVariants()
    }
}
