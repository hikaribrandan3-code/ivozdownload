import AppKit
import Foundation

/// iVoz as the suite's voice bus: when a dictation *starts with* a suite
/// keyword (in any of the three languages), the transcript is routed to the
/// target app instead of being typed into the frontmost field.
///
/// Costs nothing at runtime — this is plain string matching on text Whisper
/// already produced. Delivery uses the suite's trigger-file convention
/// (each target app polls its own Application Support trigger once a
/// second), plus `open -a` where the app should come forward.
enum SuiteIntent {
    case createTask(String)
    case remindMe(String)
    case startPomodoro
    case completeLastTask
    case speakToday
    case screenshot
    case screenRecord
    case ocr
    case askBrain(String)
    case cleanMac
    case recordMeeting
}

enum SuiteIntents {

    // MARK: - Keyword tables (normalized: lowercase, no diacritics)

    /// Order matters: more specific intents first ("record my meeting" must
    /// win over "record my screen"-style prefixes).
    private static let payloadIntents: [(keywords: [String], build: (String) -> SuiteIntent)] = [
        (createTaskKeywords, { .createTask($0) }),
        (remindMeKeywords, { .remindMe($0) }),
        (askBrainKeywords, { .askBrain($0) }),
    ]

    private static let simpleIntents: [(keywords: [String], intent: SuiteIntent)] = [
        (recordMeetingKeywords, .recordMeeting),
        (startPomodoroKeywords, .startPomodoro),
        (completeLastKeywords, .completeLastTask),
        (speakTodayKeywords, .speakToday),
        (screenshotKeywords, .screenshot),
        (screenRecordKeywords, .screenRecord),
        (ocrKeywords, .ocr),
        (cleanMacKeywords, .cleanMac),
    ]

    static let recordMeetingKeywords = [
        "record a meeting", "record the meeting", "record my meeting", "record meeting",
        "grabar una reunion", "grabar la reunion", "graba la reunion", "grabar mi reunion", "grabar reunion",
        "gravar uma reuniao", "gravar a reuniao", "grava a reuniao", "gravar minha reuniao", "gravar reuniao",
    ]

    static let createTaskKeywords = [
        "create a new task", "create a task", "create task", "add a task", "add task", "new task",
        "crear una tarea", "crea una tarea", "crear tarea", "agregar una tarea", "agrega una tarea",
        "agregar tarea", "anadir una tarea", "anade una tarea", "anadir tarea", "nueva tarea",
        "criar uma tarefa", "cria uma tarefa", "criar tarefa", "adicionar uma tarefa",
        "adiciona uma tarefa", "adicionar tarefa", "nova tarefa",
    ]

    static let remindMeKeywords = [
        "remind me",
        "recuerdame", "recordarme", "recuerda me",
        "me lembre", "lembre-me", "lembre me", "me lembra",
    ]

    static let startPomodoroKeywords = [
        "set a timer", "set timer", "start a timer", "start timer", "start focus",
        "start a pomodoro", "start the pomodoro", "start pomodoro",
        "set un temporizador", "pon un temporizador", "iniciar temporizador", "inicia el temporizador",
        "pon un timer", "inicia un timer",
        "defina um timer", "set um timer", "inicia um timer", "comeca o temporizador",
    ]

    static let completeLastKeywords = [
        "mark task as complete", "mark task complete", "mark it complete", "mark it done",
        "complete the task", "complete task", "task completed", "task complete", "task done",
        "marcar tarea como completada", "marcar tarea completada", "marcala como completada",
        "completar tarea", "completa la tarea", "tarea completada", "tarea lista",
        "marcar tarefa como concluida", "marcar tarefa concluida", "concluir tarefa",
        "conclui a tarefa", "tarefa concluida", "tarefa pronta",
    ]

    static let speakTodayKeywords = [
        "what's due today", "whats due today", "what is due today", "what do i have due today",
        "what do i have today", "what are my tasks today", "what are my tasks", "read my tasks",
        "que vence hoy", "que tengo para hoy", "que tengo hoy", "que tareas tengo hoy",
        "que tareas tengo", "cuales son mis tareas", "lee mis tareas",
        "o que vence hoje", "o que tenho para hoje", "o que tenho hoje", "que tarefas tenho hoje",
        "quais sao minhas tarefas", "leia minhas tarefas",
    ]

    static let screenshotKeywords = [
        "take a screenshot", "take screenshot", "capture the screen", "capture screen", "screenshot",
        "tomar una captura de pantalla", "tomar una captura", "toma una captura", "tomar captura",
        "captura de pantalla", "capturar pantalla", "hacer una captura",
        "tirar uma captura", "tira uma captura", "tirar captura", "captura de tela",
        "capturar tela", "tirar um print", "tira um print", "print da tela",
    ]

    static let screenRecordKeywords = [
        "start a screen recording", "start screen recording", "start a recording", "start recording",
        "record the screen", "record my screen", "record screen",
        "grabar la pantalla", "graba la pantalla", "grabar pantalla", "grabar mi pantalla",
        "iniciar grabacion", "inicia la grabacion",
        "gravar a tela", "grava a tela", "gravar tela", "gravar minha tela",
        "iniciar gravacao", "inicia a gravacao",
    ]

    static let ocrKeywords = [
        "copy text from the screen", "copy text from screen", "capture text", "scan the text", "scan text", "grab text",
        "copiar texto de la pantalla", "copia el texto", "capturar texto", "escanear texto", "escanea el texto",
        "copiar texto da tela", "copia o texto", "escaneia o texto",
    ]

    static let askBrainKeywords = [
        "ask claude", "ask cloud", "ask the ai", "ask ai", "ask ibrain", "ask brain",
        "preguntale a claude", "pregunta a claude", "preguntale a cloud",
        "preguntale a la ia", "pregunta a la ia", "preguntale a ibrain",
        "pergunte ao claude", "pergunta ao claude", "pergunte ao cloud",
        "pergunte a ia", "pergunta a ia", "pergunte ao ibrain",
    ]

    static let cleanMacKeywords = [
        "clean up my mac", "clean my mac", "clean the mac", "clean my computer",
        "limpia mi mac", "limpiar mi mac", "limpiar la mac", "limpia la mac", "limpiar mi computadora",
        "limpar meu mac", "limpa meu mac", "limpar o mac", "limpar meu computador",
    ]

    // MARK: - Matching

    /// Leading filler stripped before keyword matching ("hey, create a task…").
    private static let leadingFiller = ["hey", "oye", "ei", "ok", "okay", "please", "por favor"]

    static func match(_ text: String) -> SuiteIntent? {
        let (normalized, headOffset) = normalize(text)
        guard !normalized.isEmpty else { return nil }

        for entry in simpleIntents {
            for keyword in entry.keywords where matchesWholeOrPrefix(normalized, keyword) {
                return entry.intent
            }
        }

        for entry in payloadIntents {
            for keyword in entry.keywords where matchesWholeOrPrefix(normalized, keyword) {
                let payload = extractPayload(from: text, headOffset: headOffset, keywordLength: keyword.count)
                guard !payload.isEmpty else { return nil }
                return entry.build(payload)
            }
        }
        return nil
    }

    private static func matchesWholeOrPrefix(_ text: String, _ keyword: String) -> Bool {
        if text == keyword { return true }
        guard text.hasPrefix(keyword) else { return false }
        // Next char must be a separator so "screenshotting" doesn't match.
        let next = text[text.index(text.startIndex, offsetBy: keyword.count)]
        return next == " " || next == ":" || next == ","
    }

    /// Lowercases, folds diacritics (both length-preserving for es/pt), strips
    /// trailing punctuation, and drops leading filler words. Returns the
    /// normalized text plus how many characters were dropped from the front,
    /// so payloads can be sliced out of the *original* text with casing and
    /// accents intact.
    private static func normalize(_ text: String) -> (text: String, headOffset: Int) {
        var normalized = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
        var headOffset = 0

        // Trim leading whitespace.
        while normalized.first == " " {
            normalized.removeFirst()
            headOffset += 1
        }
        // Strip leading filler words + following separators.
        var stripped = true
        while stripped {
            stripped = false
            for filler in leadingFiller {
                if normalized.hasPrefix(filler + " ") || normalized.hasPrefix(filler + ",") {
                    let drop = filler.count + 1
                    normalized.removeFirst(drop)
                    headOffset += drop
                    while normalized.first == " " {
                        normalized.removeFirst()
                        headOffset += 1
                    }
                    stripped = true
                }
            }
        }
        // Trailing punctuation doesn't affect payload slicing.
        while let last = normalized.last, ".!?,".contains(last) {
            normalized.removeLast()
        }
        return (normalized, headOffset)
    }

    /// Slices the payload out of the original (cased, accented) text and
    /// trims leading connector words (":", "to", "de", "sobre", "about" …).
    private static func extractPayload(from original: String, headOffset: Int, keywordLength: Int) -> String {
        let start = headOffset + keywordLength
        guard start < original.count else { return "" }
        var payload = String(original.dropFirst(start))
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ":,")))
        for connector in ["to ", "que ", "de ", "para ", "about ", "sobre ", "me "] {
            if payload.lowercased().hasPrefix(connector) {
                payload = String(payload.dropFirst(connector.count))
                break
            }
        }
        // Drop a trailing period Whisper likes to add.
        while let last = payload.last, ".!".contains(last) {
            payload.removeLast()
        }
        return payload.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Actions

@MainActor
enum SuiteActions {

    /// Executes the intent and returns a localized overlay message.
    static func perform(_ intent: SuiteIntent) -> String {
        switch intent {
        case .createTask(let text), .remindMe(let text):
            appendTrigger(bundle: "com.hikari.itasks", line: text)
            launchInBackground("iTasks")
            return L("suite.task_created")
        case .startPomodoro:
            appendTrigger(bundle: "com.hikari.itasks", line: "cmd:pomodoro")
            launchInBackground("iTasks")
            return L("suite.pomodoro_started")
        case .completeLastTask:
            appendTrigger(bundle: "com.hikari.itasks", line: "cmd:complete-last")
            launchInBackground("iTasks")
            return L("suite.task_completed")
        case .speakToday:
            appendTrigger(bundle: "com.hikari.itasks", line: "cmd:speak-today")
            launchInBackground("iTasks")
            return L("suite.speaking_tasks")
        case .screenshot:
            writeTrigger(bundle: "com.hikari.icapture", content: "area")
            launchInBackground("iCapture")
            return L("suite.sent_to", "iCapture")
        case .screenRecord:
            writeTrigger(bundle: "com.hikari.icapture", content: "record")
            launchInBackground("iCapture")
            return L("suite.sent_to", "iCapture")
        case .ocr:
            writeTrigger(bundle: "com.hikari.icapture", content: "ocr")
            launchInBackground("iCapture")
            return L("suite.sent_to", "iCapture")
        case .askBrain(let question):
            writeTrigger(bundle: "com.hikari.ibrain", content: question)
            launchInForeground("iBrain")
            return L("suite.sent_to", "iBrain")
        case .cleanMac:
            writeTrigger(bundle: "com.hikari.iorganize", content: "clean")
            launchInForeground("iOrganize")
            return L("suite.sent_to", "iOrganize")
        case .recordMeeting:
            launchInForeground("MeetingAI")
            return L("suite.sent_to", "MeetingAI")
        }
    }

    // MARK: - Trigger files

    private static func triggerURL(bundle: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(bundle, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("trigger")
    }

    /// Single-command apps (iCapture, iOrganize, iBrain): last write wins.
    private static func writeTrigger(bundle: String, content: String) {
        try? content.write(to: triggerURL(bundle: bundle), atomically: true, encoding: .utf8)
    }

    /// iTasks consumes the file line-by-line — append so rapid-fire commands
    /// don't clobber each other between its 1-second polls.
    private static func appendTrigger(bundle: String, line: String) {
        let url = triggerURL(bundle: bundle)
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let combined = existing.isEmpty ? line : existing.trimmingCharacters(in: .newlines) + "\n" + line
        try? combined.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - App launching

    private static func isRunning(_ appName: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.localizedName == appName || ($0.bundleURL?.lastPathComponent == "\(appName).app")
        }
    }

    /// Launch without stealing focus — the trigger file gets consumed on the
    /// app's first poll.
    private static func launchInBackground(_ appName: String) {
        guard !isRunning(appName) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-ga", appName]
        try? process.run()
    }

    private static func launchInForeground(_ appName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName]
        try? process.run()
    }
}

// MARK: - Settings reference

/// Rows for the "Suite Commands" section in Settings — one per command,
/// with example phrases in all three languages (video-script friendly).
struct SuiteCommandReference: Identifiable {
    let id: String
    let icon: String
    let titleKey: String
    let exampleEN: String
    let exampleES: String
    let examplePT: String

    static let all: [SuiteCommandReference] = [
        .init(id: "task", icon: "checklist", titleKey: "suite.ref.create_task",
              exampleEN: "“Create a task: call mom tomorrow 3pm”",
              exampleES: "“Crear una tarea: llamar a mamá mañana 3pm”",
              examplePT: "“Criar uma tarefa: ligar para mãe amanhã 3pm”"),
        .init(id: "remind", icon: "bell", titleKey: "suite.ref.remind",
              exampleEN: "“Remind me to check the oven in 20 minutes”",
              exampleES: "“Recuérdame revisar el horno en 20 minutos”",
              examplePT: "“Me lembre de checar o forno em 20 minutos”"),
        .init(id: "pomodoro", icon: "timer", titleKey: "suite.ref.pomodoro",
              exampleEN: "Set a timer / Start the timer",
              exampleES: "Pon un timer / Pon un temporizador",
              examplePT: "Defina um timer / Inicia o temporizador"),
        .init(id: "complete", icon: "checkmark.circle", titleKey: "suite.ref.complete",
              exampleEN: "“Mark task complete”",
              exampleES: "“Marcar tarea completada”",
              examplePT: "“Marcar tarefa concluída”"),
        .init(id: "today", icon: "speaker.wave.2", titleKey: "suite.ref.today",
              exampleEN: "“What's due today?”",
              exampleES: "“¿Qué vence hoy?”",
              examplePT: "“O que vence hoje?”"),
        .init(id: "shot", icon: "camera.viewfinder", titleKey: "suite.ref.screenshot",
              exampleEN: "“Take a screenshot”",
              exampleES: "“Captura de pantalla”",
              examplePT: "“Captura de tela”"),
        .init(id: "rec", icon: "record.circle", titleKey: "suite.ref.record",
              exampleEN: "“Record my screen”",
              exampleES: "“Grabar pantalla”",
              examplePT: "“Gravar tela”"),
        .init(id: "ocr", icon: "text.viewfinder", titleKey: "suite.ref.ocr",
              exampleEN: "“Copy text from the screen”",
              exampleES: "“Copiar texto de la pantalla”",
              examplePT: "“Copiar texto da tela”"),
        .init(id: "brain", icon: "brain", titleKey: "suite.ref.ask",
              exampleEN: "“Ask Claude: how do I boil an egg?”",
              exampleES: "“Pregúntale a Claude: ¿cómo hiervo un huevo?”",
              examplePT: "“Pergunte ao Claude: como fervo um ovo?”"),
        .init(id: "clean", icon: "sparkles", titleKey: "suite.ref.clean",
              exampleEN: "“Clean my Mac”",
              exampleES: "“Limpia mi Mac”",
              examplePT: "“Limpar meu Mac”"),
        .init(id: "meeting", icon: "mic.badge.plus", titleKey: "suite.ref.meeting",
              exampleEN: "“Record a meeting”",
              exampleES: "“Grabar una reunión”",
              examplePT: "“Gravar uma reunião”"),
    ]
}
