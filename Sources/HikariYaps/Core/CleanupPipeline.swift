import Foundation

/// Post-processes raw Whisper output: artifact stripping, spoken commands,
/// filler-word removal, grammar polish, structure detection, and tone styling.
/// Deterministic and instant — runs entirely on-device with zero model cost.
struct CleanupPipeline {
    var smartFormatting: Bool
    var smartCleanup: Bool
    var tone: ToneStyle

    /// Convenience entry point: runs the fully deterministic pipeline
    /// (structure + regex cleanup + finish). Used when the local LLM isn't
    /// available.
    func process(_ raw: String, segments: [(text: String, start: Double, end: Double)]) -> String {
        let structured = structure(raw, segments: segments)
        let cleaned = smartCleanup ? regexCleanup(structured) : structured
        return finish(cleaned)
    }

    /// Stage 1: deterministic structural pass (artifact stripping, spoken
    /// commands, pause-based paragraphs). Always runs first, independent of
    /// whether cleanup comes from the LLM or the regex fallback.
    func structure(_ raw: String, segments: [(text: String, start: Double, end: Double)]) -> String {
        var text = stripWhisperArtifacts(raw)
        guard !text.isEmpty else { return text }
        if smartFormatting {
            text = applySpokenCommands(text)
            text = insertParagraphBreaks(text, segments: segments)
        }
        return text
    }

    /// Stage 2 fallback: deterministic filler-word removal + grammar tidy.
    /// Used when Smart Cleanup is on but the local LLM isn't ready yet (or
    /// generation failed) — guarantees a baseline cleanup either way.
    func regexCleanup(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return tidyGrammar(removeFillerWords(text))
    }

    /// Stage 3: list detection + capitalization + tone punctuation. Runs on
    /// the output of *either* cleanup path so formatting stays consistent.
    func finish(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = smartFormatting ? detectLists(text) : text
        result = capitalizeSentences(result)
        result = applyTone(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Stage 1: Whisper artifacts

    private func stripWhisperArtifacts(_ input: String) -> String {
        var text = input
        // Noise annotations like [BLANK_AUDIO], (music), ♪ lyrics ♪
        text = text.replacing(pattern: #"\[[^\]]*\]"#, with: "")
        text = text.replacing(pattern: #"\([^)]*(music|applause|laughter|noise|silence)[^)]*\)"#, with: "", options: [.caseInsensitive])
        text = text.replacingOccurrences(of: "♪", with: "")
        text = text.replacing(pattern: #"[ \t]+"#, with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Stage 2: Spoken commands

    private func applySpokenCommands(_ input: String) -> String {
        var text = input
        text = text.replacing(pattern: #"[,.]?\s*\b[Nn]ew paragraph\b[,.]?\s*"#, with: "\n\n")
        text = text.replacing(pattern: #"[,.]?\s*\b[Nn]ew line\b[,.]?\s*"#, with: "\n")
        return text
    }

    // MARK: - Stage 3: Paragraph breaks from long pauses

    private func insertParagraphBreaks(_ input: String, segments: [(text: String, start: Double, end: Double)]) -> String {
        guard segments.count > 1 else { return input }
        var result = input
        // When the speaker pauses > 1.75 s between segments, treat the next
        // segment as a new paragraph. Match on segment text to find the seam.
        for index in 1..<segments.count {
            let gap = segments[index].start - segments[index - 1].end
            guard gap > 1.75 else { continue }
            let nextText = segments[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard nextText.count > 3 else { continue }
            let seam = " " + nextText
            if let range = result.range(of: seam) {
                result = result.replacingCharacters(in: range, with: "\n\n" + nextText)
            }
        }
        return result
    }

    // MARK: - Stage 4: Filler words

    private static let fillerPatterns: [String] = [
        // English hesitations
        #"\b(?:[Uu]m+|[Uu]h+|[Uu]hm+|[Ee]rm+|[Aa]hm+|[Hh]mm+)\b[,.]?\s*"#,
        // "you know" / "I mean" as comma-delimited asides
        #",\s*you know,\s*"#,
        #"^[Yy]ou know,\s*"#,
        #"^[Ii] mean,\s*"#,
        // "like" only when comma-delimited on both sides
        #",\s*like,\s*"#,
        // Spanish hesitations
        #"\b[Ee]ste,\s*"#,
        #"\b[Ee]h,\s*"#,
        #"^[Pp]ues,\s*"#,
        #"^[Oo] sea,\s*"#,
        // Portuguese hesitations
        #"\b[Éé]{2,},?\s*"#,
    ]

    private static let doubledFunctionWords = [
        "the", "a", "an", "to", "i", "we", "you", "it", "is", "that", "and", "of", "in",
        "de", "la", "el", "que", "y", "en", "o", "e", "um", "uma",
    ]

    private func removeFillerWords(_ input: String) -> String {
        var text = input
        for pattern in Self.fillerPatterns {
            text = text.replacing(pattern: pattern, with: pattern.hasPrefix(",") ? ", " : "")
        }
        // Collapse doubled function words ("the the" → "the").
        for word in Self.doubledFunctionWords {
            text = text.replacing(
                pattern: "\\b(\(word))\\s+\(word)\\b",
                with: "$1",
                options: [.caseInsensitive]
            )
        }
        text = text.replacing(pattern: #"[ \t]{2,}"#, with: " ")
        text = text.replacing(pattern: #"\s+([,.!?;:])"#, with: "$1")
        text = text.replacing(pattern: #",{2,}"#, with: ",")
        return text
    }

    // MARK: - Stage 5: Grammar tidy

    private func tidyGrammar(_ input: String) -> String {
        var text = input
        // Standalone "i" → "I"
        text = text.replacing(pattern: #"\bi\b"#, with: "I")
        text = text.replacing(pattern: #"\bi'"#, with: "I'")
        // Space after sentence punctuation
        text = text.replacing(pattern: #"([.!?])([A-ZÀ-Ú])"#, with: "$1 $2")
        // Capitalize sentence starts (per line and after . ! ?)
        text = capitalizeSentences(text)
        return text
    }

    private func capitalizeSentences(_ input: String) -> String {
        guard tone != .code else { return input }
        var characters = Array(input)
        var capitalizeNext = true
        for index in characters.indices {
            let character = characters[index]
            if capitalizeNext, character.isLetter {
                characters[index] = Character(character.uppercased())
                capitalizeNext = false
            } else if ".!?\n".contains(character) {
                capitalizeNext = true
            } else if !character.isWhitespace, character != "\"", character != "'", character != "(" {
                capitalizeNext = false
            }
        }
        return String(characters)
    }

    // MARK: - Stage 6: List detection

    private func detectLists(_ input: String) -> String {
        // Convert "First, ... Second, ... Third, ..." narration into bullets
        // only when at least two ordinal markers are present.
        let ordinals = ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth"]
        let markerPattern = "(?:^|(?<=[.!?])\\s+)(\(ordinals.joined(separator: "|")))(?:ly)?[,:]\\s+"

        guard let regex = try? NSRegularExpression(pattern: markerPattern) else { return input }
        let range = NSRange(input.startIndex..., in: input)
        let matches = regex.matches(in: input, range: range)
        guard matches.count >= 2 else { return input }

        var result = input
        // Replace from the end so earlier ranges stay valid.
        for match in matches.reversed() {
            guard let full = Range(match.range, in: result) else { continue }
            result = result.replacingCharacters(in: full, with: "\n- ")
        }
        return result
    }

    // MARK: - Stage 7: Tone

    private static let casualContractions: [(String, String)] = [
        ("gonna", "going to"), ("wanna", "want to"), ("gotta", "got to"),
        ("kinda", "kind of"), ("sorta", "sort of"), ("dunno", "don't know"),
        ("lemme", "let me"), ("gimme", "give me"), ("cuz", "because"), ("'cause", "because"),
    ]

    private static let hedgePatterns: [String] = [
        #"^[Ii] think,?\s+"#,
        #"^[Ii] guess,?\s+"#,
        #"^[Ii] feel like,?\s+"#,
        #"^[Tt]o be honest,?\s+"#,
        #"^[Hh]onestly,?\s+"#,
        #"^[Bb]asically,?\s+"#,
        #"^[Ss]o,?\s+"#,
        #"^[Ww]ell,?\s+"#,
    ]

    private func applyTone(_ input: String) -> String {
        var text = input
        switch tone {
        case .message:
            // Natural: drop a lone trailing period on single-sentence messages.
            let sentenceEnders = text.filter { ".!?".contains($0) }.count
            if sentenceEnders == 1, text.hasSuffix("."), !text.contains("\n") {
                text = String(text.dropLast())
            }
        case .professional:
            for (casual, formal) in Self.casualContractions {
                text = text.replacing(pattern: "\\b\(casual)\\b", with: formal, options: [.caseInsensitive])
            }
            text = ensureTerminalPunctuation(text)
        case .concise:
            for pattern in Self.hedgePatterns {
                text = text.replacing(pattern: pattern, with: "")
            }
            text = text.replacing(pattern: #"\bin order to\b"#, with: "to")
            text = text.replacing(pattern: #",?\s*(so yeah|you know what I mean)[.!]?\s*$"#, with: "", options: [.caseInsensitive])
            text = capitalizeSentences(text)
            text = ensureTerminalPunctuation(text)
        case .code:
            // Verbatim: no trailing punctuation surprises for identifiers/commands.
            if text.hasSuffix(".") { text = String(text.dropLast()) }
        }
        return text
    }

    private func ensureTerminalPunctuation(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return trimmed }
        if !".!?:;".contains(last) {
            return trimmed + "."
        }
        return trimmed
    }
}

// MARK: - Regex convenience

extension String {
    func replacing(pattern: String, with template: String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return self }
        let range = NSRange(startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: template)
    }
}
