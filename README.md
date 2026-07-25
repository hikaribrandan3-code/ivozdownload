# iVoz ✦

**Local speech-to-text for macOS. Hold a key, talk, release — polished text appears in any app you're typing in.**

No subscriptions. No API keys. No cloud. Your voice never leaves your Mac. The AI runs entirely on your Apple Silicon chip (M1/M2/M3/M4) using the Neural Engine and GPU.

---

## Download

1. Download `iVoz.zip` from the link above.
2. Unzip and drag **iVoz.app** to your `/Applications` folder.
3. Open it.

---

## First-time setup (2 minutes)

The app will walk you through this on the Home screen:

1. **Microphone** — click **Grant** so it can hear you.
2. **Accessibility** — click **Open Settings**, go to **Privacy & Security → Accessibility**, add **iVoz**, and check the box. (If it was already listed, remove it and add it again after reinstalling.)
3. **Model download** — wait for the speech model to download (~145 MB, one-time). A "Ready" pill appears when it's done.
4. **Smart Cleanup** (optional, on by default) — downloads a ~1 GB local grammar model on first use. Progress shows under the Smart Cleanup card.

That's it. You're fully offline after that.

---

## How to use

1. Click into any text field — ChatGPT, Notes, browser, code editor, anywhere.
2. **Hold Ctrl** (or your chosen hotkey), speak naturally.
3. **Release** — the text types itself into the field. A tiny red dot + waveform bars appear at the bottom while recording.

**Pro tips:**
- Say "new line" or "new paragraph" to insert breaks.
- Toggle **Smart Cleanup** to strip filler words ("um", "uh", "like") and polish grammar using a local AI model.
- Pick a **Tone** (Message, Professional, Concise, Code) to shape how the output reads.
- Add **Vocabulary** words and **Snippets** (e.g., "my email" → your full address) for custom shortcuts.

---

## Features

- **Global hotkey** — Hold-to-talk or Tap-to-toggle. Change the key in Settings. Keyboard shortcuts (like Ctrl+C) are detected and ignored.
- **Works in every app** — uses a smart clipboard-paste strategy with automatic clipboard restore. Falls back gracefully in password fields.
- **Whisper on the Neural Engine** — [WhisperKit](https://github.com/argmaxinc/WhisperKit) runs OpenAI's Whisper via Core ML on your Mac's Neural Engine. Default model is fast and accurate; toggle **Enhanced Recognition** for a larger model that handles accents and noise better.
- **Smart formatting** — auto-detects lists, paragraphs (from speech pauses), sentence capitalization, and spoken commands.
- **Smart Cleanup** — a real local LLM (Qwen2.5-1.5B-Instruct) strips filler words and fixes grammar in ~0.3–0.6 seconds. A deterministic rule-based pass runs underneath as a safety net.
- **History** — searchable transcription log with date grouping, word/session counts, export to text or JSON.
- **Vocabulary & Snippets** — teach the app custom words (names, jargon) and spoken shortcuts that expand into full text.
- **Input device selector** — pick your mic, see a live level meter, and test it.
- **Launch at login** — optional.

---

## System requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Mac (M1 / M2 / M3 / M4)
- ~1.5 GB free space for models (downloaded once on first launch)

---

## Privacy

Everything runs locally. No audio is sent to any server. No account needed. No telemetry. Your transcriptions are stored only on your Mac in `~/Library/Application Support/iVoz/`.

---

## Update

Click **Update** in the left sidebar of the app to rebuild from the latest source and reinstall automatically.

---

*Built with Swift, WhisperKit, and llama.cpp. Inspired by Whispr Flow — rebuilt to be free, offline, and yours.*
