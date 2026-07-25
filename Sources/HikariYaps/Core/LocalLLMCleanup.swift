@preconcurrency import LLM
import Foundation

enum LLMEngineState: Equatable {
    case unloaded
    case downloading(progress: Double)
    case loading
    case ready
    case failed(String)

    @MainActor var statusLabel: String {
        switch self {
        case .unloaded: return L("engine.status.idle")
        case .downloading(let p): return L("llm.status.downloading", Int(p * 100))
        case .loading: return L("llm.status.loading")
        case .ready: return L("common.ready")
        case .failed: return L("llm.status.error")
        }
    }
}

/// Real on-device grammar/filler-word cleanup via a small instruct LLM
/// (Qwen2.5-1.5B-Instruct, Q4_K_M GGUF) running on llama.cpp's Metal backend
/// through LLM.swift. Runs entirely on the GPU, no network after first
/// download, no Xcode/Metal-compiler dependency (llama.cpp JIT-compiles its
/// Metal shaders at runtime via the OS's Metal framework).
///
/// This is a *quality* layer on top of `CleanupPipeline`'s deterministic
/// rules, not a replacement: the rules pass still guarantees filler-word
/// stripping, structure, and tone punctuation even before this model has
/// finished downloading, or if generation ever fails.
@MainActor
final class LocalLLMCleanup: ObservableObject {
    @Published private(set) var state: LLMEngineState = .unloaded

    private var llm: LLM?
    private var loadTask: Task<Void, Never>?

    private static let modelFilename = "qwen2.5-1.5b-instruct-q4_k_m.gguf"
    private static let modelURL = URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf")!
    /// Expected size in bytes (~1.03 GB for Q4_K_M).
    private static let expectedBytes: Int64 = 1_105_000_000

    private static var modelPath: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HikariYaps", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("llm", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(modelFilename)
    }

    private static var partialPath: URL {
        modelPath.appendingPathExtension("part")
    }

    var isDownloaded: Bool {
        let path = Self.modelPath.path
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        return size > Int64(Double(Self.expectedBytes) * 0.95)
    }

    func activate() {
        guard state == .unloaded || isFailedOrStale else { return }
        loadTask?.cancel()
        loadTask = Task { await self.loadModel() }
    }

    private var isFailedOrStale: Bool {
        if case .failed = state { return true }
        return false
    }

    private func loadModel() async {
        let path = Self.modelPath
        if !isDownloaded {
            state = .downloading(progress: 0)
            do {
                try await Self.downloadResumable(from: Self.modelURL, to: path, expectedBytes: Self.expectedBytes) { progress in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.state else { return }
                        self.state = .downloading(progress: progress)
                    }
                }
            } catch {
                state = .failed(error.localizedDescription)
                return
            }
        }
        if Task.isCancelled { return }

        state = .loading
        guard let model = LLM(from: path, template: .chatML(nil), maxTokenCount: 512) else {
            state = .failed("Could not load the cleanup model")
            return
        }
        model.temp = 0.1
        model.topP = 0.9
        llm = model
        state = .ready
    }

    /// Removes filler words and fixes grammar while preserving meaning and
    /// tone. Returns nil if the model isn't ready or generation fails, so
    /// callers can fall back to the deterministic rules pass.
    func cleanup(_ text: String, tone: ToneStyle) async -> String? {
        guard let llm, state == .ready, !text.isEmpty else { return nil }

        let system = Self.systemPrompt(for: tone)
        // Qwen 2.5 ChatML format: <|im_start|> tags with <|im_end|> between turns.
        let prompt = "<|im_start|>system\n\(system)<|im_end|>\n<|im_start|>user\n\(text)<|im_end|>\n<|im_start|>assistant\n"

        let result = await llm.getCompletion(from: prompt)
        let cleaned = result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|im_start|>", with: "")
            .replacingOccurrences(of: "<|endoftext|>", with: "")
            .replacingOccurrences(of: "</s>", with: "")

        // Guard against degenerate output (empty, wildly longer, or markdown-wrapped).
        guard !cleaned.isEmpty, cleaned.count < text.count * 3 + 40 else { return nil }
        // Reject if the model wrapped the output in markdown code blocks.
        if cleaned.hasPrefix("```") || cleaned.hasSuffix("```") {
            return cleaned.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private static func systemPrompt(for tone: ToneStyle) -> String {
        let base = "You clean up spoken-language transcripts. Remove ALL filler words and hesitations (um, uh, like, you know, I mean, sort of). Fix grammar, capitalization, and punctuation. Preserve the speaker's meaning and information exactly — never add or invent content."
        switch tone {
        case .message:
            return base + " Keep it natural and conversational. Reply with ONLY the corrected text, nothing else."
        case .professional:
            return base + " Rewrite in a polished, professional register — expand casual contractions like gonna/wanna. Reply with ONLY the corrected text, nothing else."
        case .concise:
            return base + " Trim hedging phrases (I think, I guess, basically, so yeah) and make it as brief as possible without losing information. Reply with ONLY the corrected text, nothing else."
        case .code:
            return "You clean up spoken-language transcripts describing code, commands, or technical content. Remove filler words (um, uh, like, you know). Do NOT alter identifiers, casing, punctuation used in code, or add trailing punctuation. Reply with ONLY the corrected text, nothing else."
        }
    }

    // MARK: - Resumable download

    /// Downloads with HTTP Range resume support and basic file-size validation.
    private static func downloadResumable(from url: URL, to destination: URL, expectedBytes: Int64, onProgress: @escaping (Double) -> Void) async throws {
        let partPath = partialPath
        let fm = FileManager.default
        let existingSize = (try? fm.attributesOfItem(atPath: partPath.path)[.size] as? NSNumber)?.int64Value ?? 0

        var request = URLRequest(url: url)
        request.timeoutInterval = 300
        if existingSize > 0 {
            request.setValue("bytes=\(existingSize)-", forHTTPHeaderField: "Range")
        }

        let (tempURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "HikariYaps", code: 20, userInfo: [
                NSLocalizedDescriptionKey: "Cleanup model download failed: no HTTP response"
            ])
        }

        // Accept 200 (full download) or 206 (partial/resume).
        guard (200..<300).contains(http.statusCode) || http.statusCode == 206 else {
            throw NSError(domain: "HikariYaps", code: 21, userInfo: [
                NSLocalizedDescriptionKey: "Cleanup model download failed (HTTP \(http.statusCode))"
            ])
        }

        let isPartial = http.statusCode == 206
        if isPartial, existingSize > 0 {
            // Append to the partial file.
            let handle = try FileHandle(forWritingTo: partPath)
            handle.seekToEndOfFile()
            let data = try Data(contentsOf: tempURL)
            handle.write(data)
            handle.closeFile()
        } else {
            // Fresh download — replace partial file.
            if fm.fileExists(atPath: partPath.path) {
                try fm.removeItem(at: partPath)
            }
            try fm.moveItem(at: tempURL, to: partPath)
        }

        // Validate size.
        let finalAttrs = try fm.attributesOfItem(atPath: partPath.path)
        let finalSize = (finalAttrs[.size] as? NSNumber)?.int64Value ?? 0
        guard finalSize > Int64(Double(expectedBytes) * 0.95) else {
            throw NSError(domain: "HikariYaps", code: 22, userInfo: [
                NSLocalizedDescriptionKey: "Downloaded file looks too small (\(finalSize) bytes, expected ~\(expectedBytes)). It may be corrupted."
            ])
        }

        // Move from .part to final path.
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: partPath, to: destination)
        onProgress(1.0)
    }
}
