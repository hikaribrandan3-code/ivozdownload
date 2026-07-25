import Foundation

/// Master translation table. Keys are namespaced `area.thing`. Add the
/// English row first when adding a new key — it's the fallback if a
/// translation is ever missing.
enum Strings {
    static let table: [String: [AppLanguage: String]] = [

        // MARK: - Common
        "common.add": [.es: "Agregar", .en: "Add", .pt: "Adicionar"],
        "common.cancel": [.es: "Cancelar", .en: "Cancel", .pt: "Cancelar"],
        "common.change": [.es: "Cambiar", .en: "Change", .pt: "Alterar"],
        "common.clear": [.es: "Borrar", .en: "Clear", .pt: "Limpar"],
        "common.close": [.es: "Cerrar", .en: "Close", .pt: "Fechar"],
        "common.copy_help": [.es: "Copiar", .en: "Copy", .pt: "Copiar"],
        "common.default": [.es: "Predeterminado", .en: "Default", .pt: "Padrão"],
        "common.dismiss": [.es: "Cerrar", .en: "Dismiss", .pt: "Dispensar"],
        "common.delete_help": [.es: "Eliminar", .en: "Delete", .pt: "Excluir"],
        "common.export": [.es: "Exportar", .en: "Export", .pt: "Exportar"],
        "common.grant": [.es: "Conceder", .en: "Grant", .pt: "Conceder"],
        "common.open_settings": [.es: "Abrir Preferencias", .en: "Open Settings", .pt: "Abrir Preferências"],
        "common.ready": [.es: "Listo", .en: "Ready", .pt: "Pronto"],
        "common.stop": [.es: "Detener", .en: "Stop", .pt: "Parar"],
        "common.today": [.es: "Hoy", .en: "Today", .pt: "Hoje"],
        "common.yesterday": [.es: "Ayer", .en: "Yesterday", .pt: "Ontem"],

        // MARK: - Navigation / sidebar
        "nav.home": [.es: "Inicio", .en: "Home", .pt: "Início"],
        "nav.vocabulary": [.es: "Vocabulario", .en: "Vocabulary", .pt: "Vocabulário"],
        "nav.snippets": [.es: "Fragmentos", .en: "Snippets", .pt: "Trechos"],
        "nav.suite_commands": [.es: "Comandos Suite", .en: "Suite Commands", .pt: "Comandos Suite"],
        "nav.settings": [.es: "Preferencias", .en: "Settings", .pt: "Preferências"],
        "nav.update": [.es: "Actualizar", .en: "Update", .pt: "Atualizar"],
        "sidebar.hold_to_dictate": [.es: "MANTENÉ PARA DICTAR", .en: "HOLD TO DICTATE", .pt: "SEGURE PARA DITAR"],
        "sidebar.tap_to_dictate": [.es: "TOCÁ PARA DICTAR", .en: "TAP TO DICTATE", .pt: "TOQUE PARA DITAR"],

        // MARK: - Home
        "home.greeting.morning": [.es: "Buenos días", .en: "Good morning", .pt: "Bom dia"],
        "home.greeting.afternoon": [.es: "Buenas tardes", .en: "Good afternoon", .pt: "Boa tarde"],
        "home.greeting.evening": [.es: "Buenas noches", .en: "Good evening", .pt: "Boa noite"],
        "home.stat.words_today": [.es: "Palabras hoy", .en: "Words today", .pt: "Palavras hoje"],
        "home.stat.sessions": [.es: "Sesiones", .en: "Sessions", .pt: "Sessões"],
        "home.stat.avg_wpm": [.es: "PPM promedio", .en: "Avg WPM", .pt: "PPM médio"],
        "home.stat.all_time": [.es: "Total histórico", .en: "All time", .pt: "Total histórico"],
        "home.stat.min_saved": [.es: "~%d min ahorrados", .en: "~%d min saved", .pt: "~%d min economizados"],
        "home.smart_cleanup.subtitle": [
            .es: "Pulí gramática y muletillas con un modelo de IA local",
            .en: "Polish grammar and filler words with a local AI model",
            .pt: "Aprimore a gramática e remova vícios de linguagem com um modelo de IA local",
        ],
        "home.quickadd.word_placeholder": [.es: "Agregar una palabra o nombre…", .en: "Add a word or name…", .pt: "Adicionar uma palavra ou nome…"],
        "home.snippet.trigger_placeholder": [.es: "Frase disparadora…", .en: "Trigger phrase…", .pt: "Frase de ativação…"],
        "home.snippet.content_placeholder": [.es: "Texto a expandir…", .en: "Expanded text…", .pt: "Texto expandido…"],
        "home.quickadd.hint": [
            .es: "Las palabras personalizadas mejoran el reconocimiento; los fragmentos se expanden al decirlos.",
            .en: "Custom words bias recognition; snippets expand when spoken.",
            .pt: "Palavras personalizadas melhoram o reconhecimento; os trechos se expandem ao serem ditos.",
        ],
        "home.history.title": [.es: "Historial", .en: "History", .pt: "Histórico"],
        "home.history.search_placeholder": [.es: "Buscar transcripciones…", .en: "Search transcriptions…", .pt: "Buscar transcrições…"],
        "home.history.clear_confirm_title": [
            .es: "¿Borrar todo el historial de transcripciones?",
            .en: "Clear all transcription history?",
            .pt: "Limpar todo o histórico de transcrições?",
        ],
        "home.history.clear_confirm_button": [.es: "Borrar historial", .en: "Clear History", .pt: "Limpar histórico"],
        "home.history.empty_hold": [.es: "Mantené %@ y empezá a hablar", .en: "Hold %@ and start talking", .pt: "Segure %@ e comece a falar"],
        "home.history.empty_sub": [
            .es: "Tus transcripciones van a aparecer acá.",
            .en: "Your transcriptions will appear here.",
            .pt: "Suas transcrições vão aparecer aqui.",
        ],
        "home.history.words_count": [.es: "%d palabras", .en: "%d words", .pt: "%d palavras"],
        "home.history.session_singular": [.es: "%d sesión", .en: "%d session", .pt: "%d sessão"],
        "home.history.session_plural": [.es: "%d sesiones", .en: "%d sessions", .pt: "%d sessões"],
        "permissions.title": [
            .es: "Terminá de configurar Hikari Yaps",
            .en: "Finish setting up Hikari Yaps",
            .pt: "Termine de configurar o Hikari Yaps",
        ],
        "permissions.microphone.title": [.es: "Micrófono", .en: "Microphone", .pt: "Microfone"],
        "permissions.microphone.detail": [.es: "Necesario para escuchar tu voz.", .en: "Needed to hear your voice.", .pt: "Necessário para ouvir sua voz."],
        "permissions.accessibility.title": [.es: "Accesibilidad", .en: "Accessibility", .pt: "Acessibilidade"],
        "permissions.accessibility.detail": [
            .es: "Necesario para el atajo global y para escribir en cualquier app.",
            .en: "Needed for the global hotkey and to type into any app.",
            .pt: "Necessário para o atalho global e para digitar em qualquer app.",
        ],

        // MARK: - Settings — sections
        "settings.section.language": [.es: "Idioma", .en: "Language", .pt: "Idioma"],
        "settings.section.license": [.es: "Licencia", .en: "License", .pt: "Licença"],
        "settings.section.hotkey": [.es: "Atajo", .en: "Hotkey", .pt: "Atalho"],
        "settings.section.audio": [.es: "Audio", .en: "Audio", .pt: "Áudio"],
        "settings.section.ai": [.es: "IA y salida", .en: "AI & Output", .pt: "IA e saída"],
        "settings.section.behavior": [.es: "Comportamiento", .en: "Behavior", .pt: "Comportamento"],

        // MARK: - License activation
        "license.status_title": [.es: "Estado de la licencia", .en: "License status", .pt: "Status da licença"],
        "license.status_pro": [.es: "iVoz Pro activado", .en: "iVoz Pro activated", .pt: "iVoz Pro ativado"],
        "license.status_pro_subtitle": [
            .es: "Palabras ilimitadas, para siempre.",
            .en: "Unlimited words, forever.",
            .pt: "Palavras ilimitadas, para sempre.",
        ],
        "license.status_trial": [.es: "Prueba gratis", .en: "Free trial", .pt: "Teste grátis"],
        "license.status_trial_subtitle_format": [
            .es: "%d días restantes de acceso completo",
            .en: "%d days left of full access",
            .pt: "%d dias restantes de acesso completo",
        ],
        "license.status_expired": [.es: "Prueba finalizada", .en: "Trial ended", .pt: "Teste encerrado"],
        "license.status_expired_subtitle_format": [
            .es: "%d / %d palabras usadas este mes",
            .en: "%d / %d words used this month",
            .pt: "%d / %d palavras usadas este mês",
        ],
        "license.code_placeholder": [.es: "Código de activación", .en: "Activation code", .pt: "Código de ativação"],
        "license.activate_button": [.es: "Activar", .en: "Activate", .pt: "Ativar"],
        "license.buy_button": [.es: "Comprar iVoz Pro — $9.99", .en: "Buy iVoz Pro — $9.99", .pt: "Comprar iVoz Pro — $9.99"],
        "license.error_empty": [.es: "Ingresá un código", .en: "Enter a code", .pt: "Digite um código"],
        "license.error_invalid": [
            .es: "Código inválido o ya utilizado",
            .en: "Invalid or already-used code",
            .pt: "Código inválido ou já utilizado",
        ],
        "license.error_network": [
            .es: "Error de conexión. Intentá de nuevo.",
            .en: "Connection error. Try again.",
            .pt: "Erro de conexão. Tente novamente.",
        ],
        "license.limit_title": [
            .es: "Límite mensual de palabras alcanzado",
            .en: "Monthly word limit reached",
            .pt: "Limite mensal de palavras atingido",
        ],
        "license.limit_subtitle": [
            .es: "Usaste 3.500 palabras este mes. Activá tu código o comprá iVoz Pro para seguir dictando.",
            .en: "You've used 3,500 words this month. Activate your code or buy iVoz Pro to keep dictating.",
            .pt: "Você usou 3.500 palavras este mês. Ative seu código ou compre o iVoz Pro para continuar ditando.",
        ],
        "license.limit_footer": [
            .es: "¿Ya compraste iVoz Pro? Ingresá el código que recibiste al pagar.",
            .en: "Already bought iVoz Pro? Enter the code you got at checkout.",
            .pt: "Já comprou o iVoz Pro? Digite o código que recebeu na compra.",
        ],

        // MARK: - Settings — language selector
        "settings.ui_language.subtitle": [
            .es: "Idioma usado en toda la aplicación",
            .en: "Language used throughout the app",
            .pt: "Idioma usado em todo o aplicativo",
        ],

        // MARK: - Settings — hotkey
        "settings.hotkey.title": [.es: "Atajo", .en: "Hotkey", .pt: "Atalho"],
        "settings.hotkey.subtitle_hold": [
            .es: "Mantené presionado para hablar, soltá para transcribir",
            .en: "Hold to talk, release to transcribe",
            .pt: "Segure para falar, solte para transcrever",
        ],
        "settings.hotkey.subtitle_tap": [
            .es: "Tocá para empezar, tocá de nuevo para transcribir",
            .en: "Tap to start, tap again to transcribe",
            .pt: "Toque para começar, toque novamente para transcrever",
        ],
        "settings.hotkey.press_modifier": [.es: "Presioná un modificador…", .en: "Press a modifier…", .pt: "Pressione um modificador…"],
        "settings.hotkey_behavior.title": [.es: "Comportamiento del atajo", .en: "Hotkey behavior", .pt: "Comportamento do atalho"],
        "settings.hotkey_behavior.subtitle_hold": [
            .es: "Graba solo mientras se mantiene presionada la tecla",
            .en: "Record only while the key is held",
            .pt: "Grava apenas enquanto a tecla estiver pressionada",
        ],
        "settings.hotkey_behavior.subtitle_tap": [
            .es: "Un toque rápido activa o detiene la grabación",
            .en: "Quick tap toggles recording",
            .pt: "Um toque rápido ativa ou desativa a gravação",
        ],
        "hotkey.behavior.hold": [.es: "Mantener", .en: "Hold", .pt: "Segurar"],
        "hotkey.behavior.tap": [.es: "Tocar", .en: "Tap", .pt: "Tocar"],

        // MARK: - Settings — audio
        "settings.input_device.title": [.es: "Dispositivo de entrada", .en: "Input device", .pt: "Dispositivo de entrada"],
        "settings.input_device.subtitle": [
            .es: "Micrófono usado para grabar",
            .en: "Microphone used for recording",
            .pt: "Microfone usado para gravação",
        ],
        "settings.input_level.title": [.es: "Nivel de entrada", .en: "Input level", .pt: "Nível de entrada"],
        "settings.input_level.test_button": [.es: "Probar micrófono", .en: "Test mic", .pt: "Testar microfone"],

        // MARK: - Settings — AI & output
        "settings.smart_formatting.title": [.es: "Formato inteligente", .en: "Smart formatting", .pt: "Formatação inteligente"],
        "settings.smart_formatting.subtitle": [
            .es: "Formatea listas, párrafos y estructura automáticamente",
            .en: "Automatically format lists, paragraphs, and structure",
            .pt: "Formata listas, parágrafos e estrutura automaticamente",
        ],
        "ai.smart_cleanup.title": [.es: "Limpieza inteligente", .en: "Smart Cleanup", .pt: "Limpeza inteligente"],
        "settings.smart_cleanup.subtitle_off": [
            .es: "Pulí gramática y muletillas con un modelo de IA local (Qwen2.5-1.5B)",
            .en: "Polish grammar and filler words with a local AI model (Qwen2.5-1.5B)",
            .pt: "Aprimore a gramática e remova vícios de linguagem com um modelo de IA local (Qwen2.5-1.5B)",
        ],
        "settings.smart_cleanup.subtitle_ready": [
            .es: "Pulí gramática y muletillas con un modelo de IA local — listo",
            .en: "Polish grammar and filler words with a local AI model — ready",
            .pt: "Aprimore a gramática e remova vícios de linguagem com um modelo de IA local — pronto",
        ],
        "settings.smart_cleanup.subtitle_failed": [
            .es: "El modelo local no cargó — usando limpieza basada en reglas",
            .en: "Local model failed to load — falling back to rule-based cleanup",
            .pt: "O modelo local falhou ao carregar — usando limpeza baseada em regras",
        ],
        "ai.tone.title": [.es: "Tono", .en: "Tone", .pt: "Tom"],
        "tone.message": [.es: "Mensaje", .en: "Message", .pt: "Mensagem"],
        "tone.professional": [.es: "Profesional", .en: "Professional", .pt: "Profissional"],
        "tone.concise": [.es: "Conciso", .en: "Concise", .pt: "Conciso"],
        "tone.code": [.es: "Código", .en: "Code", .pt: "Código"],
        "tone.blurb.message": [.es: "Tono natural y conversacional", .en: "Natural conversational tone", .pt: "Tom natural e conversacional"],
        "tone.blurb.professional": [.es: "Escritura pulida y formal", .en: "Polished, formal writing", .pt: "Escrita polida e formal"],
        "tone.blurb.concise": [.es: "Reducido a lo esencial", .en: "Trimmed down to essentials", .pt: "Reduzido ao essencial"],
        "tone.blurb.code": [.es: "Textual, sin puntuación automática", .en: "Verbatim, no auto-punctuation", .pt: "Literal, sem pontuação automática"],
        "settings.enhanced_recognition.title": [.es: "Reconocimiento mejorado", .en: "Enhanced Recognition", .pt: "Reconhecimento aprimorado"],
        "settings.enhanced_recognition.subtitle": [
            .es: "Mejor precisión con acentos y ruido, un poco más lento",
            .en: "Better accuracy with accents and noise, slightly slower",
            .pt: "Melhor precisão com sotaques e ruído, um pouco mais lento",
        ],
        "settings.dictation_language.title": [.es: "Idioma", .en: "Language", .pt: "Idioma"],
        "settings.dictation_language.subtitle": [
            .es: "Idioma hablado en tus dictados",
            .en: "Language spoken in your dictations",
            .pt: "Idioma falado nos seus ditados",
        ],
        "language.auto_detect": [.es: "Detección automática", .en: "Auto-detect", .pt: "Detecção automática"],
        "settings.standard_model.title": [.es: "Modelo estándar", .en: "Standard model", .pt: "Modelo padrão"],
        "settings.standard_model.subtitle": [
            .es: "Usado cuando el Reconocimiento mejorado está apagado",
            .en: "Used when Enhanced Recognition is off",
            .pt: "Usado quando o Reconhecimento aprimorado está desligado",
        ],
        "settings.enhanced_model.title": [.es: "Modelo mejorado", .en: "Enhanced model", .pt: "Modelo aprimorado"],
        "settings.enhanced_model.subtitle": [
            .es: "Usado cuando el Reconocimiento mejorado está encendido",
            .en: "Used when Enhanced Recognition is on",
            .pt: "Usado quando o Reconhecimento aprimorado está ligado",
        ],
        "settings.model.downloaded_help": [.es: "Descargado", .en: "Downloaded", .pt: "Baixado"],

        // MARK: - Settings — behavior
        "settings.launch_at_login.title": [.es: "Iniciar con el sistema", .en: "Launch at login", .pt: "Iniciar ao fazer login"],
        "settings.launch_at_login.subtitle": [
            .es: "Iniciar Hikari Yaps al iniciar sesión",
            .en: "Start Hikari Yaps when you sign in",
            .pt: "Iniciar o Hikari Yaps ao entrar na sua conta",
        ],
        "settings.auto_dismiss.title": [.es: "Ocultar overlay automáticamente", .en: "Auto-dismiss overlay", .pt: "Ocultar overlay automaticamente"],
        "settings.auto_dismiss.subtitle": [
            .es: "Ocultar el overlay después de insertar el texto",
            .en: "Hide the overlay after text is injected",
            .pt: "Ocultar o overlay após o texto ser inserido",
        ],
        "settings.completion_sound.title": [.es: "Sonido de finalización", .en: "Completion sound", .pt: "Som de conclusão"],
        "settings.completion_sound.subtitle": [
            .es: "Reproducir un sonido cuando termina la transcripción",
            .en: "Play a sound when transcription finishes",
            .pt: "Tocar um som quando a transcrição terminar",
        ],
        "settings.injection_method.title": [.es: "Método de inserción", .en: "Insertion method", .pt: "Método de inserção"],
        "settings.injection_method.subtitle": [
            .es: "Cómo se coloca el texto en la app enfocada",
            .en: "How text is placed into the focused app",
            .pt: "Como o texto é colocado no app em foco",
        ],
        "injection.auto": [.es: "Automático (recomendado)", .en: "Automatic (recommended)", .pt: "Automático (recomendado)"],
        "injection.paste": [.es: "Pegar", .en: "Paste", .pt: "Colar"],
        "injection.type": [.es: "Escritura simulada", .en: "Simulated typing", .pt: "Digitação simulada"],

        // MARK: - Vocabulary
        "vocabulary.page_subtitle": [
            .es: "Los nombres, marcas y jerga que agregues acá mejoran el reconocimiento de voz para que salgan bien escritos.",
            .en: "Names, brands, and jargon added here bias speech recognition so they come out spelled right.",
            .pt: "Nomes, marcas e jargões adicionados aqui ajudam o reconhecimento de voz a escrevê-los corretamente.",
        ],
        "vocabulary.add_placeholder": [.es: "Agregar una palabra o nombre…", .en: "Add a word or name…", .pt: "Adicionar uma palavra ou nome…"],
        "vocabulary.empty_title": [.es: "Todavía no hay palabras personalizadas", .en: "No custom words yet", .pt: "Ainda não há palavras personalizadas"],
        "vocabulary.empty_hint": [
            .es: "Probá agregando nombres como “Kimmy”, “FoodSpot” o “Supabase”.",
            .en: "Try adding names like “Kimmy”, “FoodSpot”, or “Supabase”.",
            .pt: "Tente adicionar nomes como “Kimmy”, “FoodSpot” ou “Supabase”.",
        ],

        // MARK: - Snippets
        "snippets.page_subtitle": [
            .es: "Decí una frase disparadora y se inserta su fragmento en su lugar. Probá “mi email” → tu dirección.",
            .en: "Say a trigger phrase and its snippet is injected instead. Try “my email” → your address.",
            .pt: "Diga uma frase de ativação e o trecho correspondente é inserido no lugar. Tente “meu email” → seu endereço.",
        ],
        "snippets.trigger_placeholder_full": [
            .es: "Frase disparadora — ej. “mi email”",
            .en: "Trigger phrase — e.g. “my email”",
            .pt: "Frase de ativação — ex. “meu email”",
        ],
        "snippets.content_placeholder_full": [
            .es: "Contenido del fragmento — lo que se escribe",
            .en: "Snippet content — what gets typed",
            .pt: "Conteúdo do trecho — o que será digitado",
        ],
        "snippets.add_button": [.es: "Agregar fragmento", .en: "Add Snippet", .pt: "Adicionar trecho"],
        "snippets.empty_title": [.es: "Todavía no hay fragmentos", .en: "No snippets yet", .pt: "Ainda não há trechos"],
        "snippets.empty_hint": [
            .es: "Los fragmentos son ideales para emails, direcciones y respuestas prearmadas.",
            .en: "Snippets are perfect for emails, addresses, and canned replies.",
            .pt: "Os trechos são perfeitos para emails, endereços e respostas prontas.",
        ],

        // MARK: - Update sheet
        "update.version": [.es: "Versión %@", .en: "Version %@", .pt: "Versão %@"],
        "update.rebuilding": [.es: "Recompilando desde el código fuente…", .en: "Rebuilding from source…", .pt: "Recompilando a partir do código-fonte…"],
        "update.success": [.es: "¡Actualizado con éxito!", .en: "Updated successfully!", .pt: "Atualizado com sucesso!"],
        "update.relaunch_button": [.es: "Reiniciar Hikari Yaps", .en: "Relaunch Hikari Yaps", .pt: "Reiniciar o Hikari Yaps"],
        "update.description": [
            .es: "Esto recompila Hikari Yaps desde el código fuente local y lo reinstala en /Applications.",
            .en: "This rebuilds Hikari Yaps from the local project source and reinstalls to /Applications.",
            .pt: "Isso recompila o Hikari Yaps a partir do código-fonte local e o reinstala em /Applications.",
        ],
        "update.rebuild_button": [.es: "Recompilar y reinstalar", .en: "Rebuild & Reinstall", .pt: "Recompilar e reinstalar"],

        // MARK: - Menu bar
        "menubar.open": [.es: "Abrir Hikari Yaps", .en: "Open Hikari Yaps", .pt: "Abrir Hikari Yaps"],
        "menubar.quit": [.es: "Salir de Hikari Yaps", .en: "Quit Hikari Yaps", .pt: "Sair do Hikari Yaps"],

        // MARK: - Engine / cleanup status
        "engine.status.idle": [.es: "Inactivo", .en: "Idle", .pt: "Ocioso"],
        "engine.status.downloading": [.es: "Descargando modelo %d%%", .en: "Downloading model %d%%", .pt: "Baixando modelo %d%%"],
        "engine.status.loading": [.es: "Cargando modelo…", .en: "Loading model…", .pt: "Carregando modelo…"],
        "engine.status.transcribing": [.es: "Transcribiendo…", .en: "Transcribing…", .pt: "Transcrevendo…"],
        "engine.status.error": [.es: "Error del motor", .en: "Engine error", .pt: "Erro no motor"],
        "llm.status.downloading": [.es: "Descargando modelo de limpieza %d%%", .en: "Downloading cleanup model %d%%", .pt: "Baixando modelo de limpeza %d%%"],
        "llm.status.loading": [.es: "Cargando modelo de limpieza…", .en: "Loading cleanup model…", .pt: "Carregando modelo de limpeza…"],
        "llm.status.error": [.es: "Error del modelo de limpieza", .en: "Cleanup model error", .pt: "Erro no modelo de limpeza"],
        "error.help_text": [
            .es: "Si hay problemas de conexión, cierra iVoz y reinicia desde Finder.",
            .en: "If there are connection issues, close iVoz and restart from Finder.",
            .pt: "Se houver problemas de conexão, feche iVoz e reinicie pelo Finder.",
        ],

        // MARK: - Suite voice commands
        "suite.task_created": [.es: "Tarea creada en iTasks ✓", .en: "Task created in iTasks ✓", .pt: "Tarefa criada no iTasks ✓"],
        "suite.pomodoro_started": [.es: "Pomodoro iniciado ✓", .en: "Pomodoro started ✓", .pt: "Pomodoro iniciado ✓"],
        "suite.task_completed": [.es: "Tarea completada ✓", .en: "Task completed ✓", .pt: "Tarefa concluída ✓"],
        "suite.speaking_tasks": [.es: "Leyendo tus tareas…", .en: "Reading your tasks…", .pt: "Lendo suas tarefas…"],
        "suite.sent_to": [.es: "Enviado a %@ ✓", .en: "Sent to %@ ✓", .pt: "Enviado ao %@ ✓"],
        "settings.section.suite": [.es: "Comandos de la suite", .en: "Suite Commands", .pt: "Comandos da suíte"],
        "settings.suite_commands.title": [.es: "Comandos de voz para iSuite", .en: "iSuite voice commands", .pt: "Comandos de voz para iSuite"],
        "settings.suite_commands.subtitle": [
            .es: "Empezá el dictado con una palabra clave para controlar las otras apps",
            .en: "Start a dictation with a keyword to control the other apps",
            .pt: "Comece o ditado com uma palavra-chave para controlar os outros apps",
        ],
        "suite.ref.create_task": [.es: "Crear una tarea (iTasks)", .en: "Create a task (iTasks)", .pt: "Criar uma tarefa (iTasks)"],
        "suite.ref.remind": [.es: "Recordatorio rápido (iTasks)", .en: "Quick reminder (iTasks)", .pt: "Lembrete rápido (iTasks)"],
        "suite.ref.pomodoro": [.es: "Configurar Temporizador (iTasks)", .en: "Set a Timer (iTasks)", .pt: "Configurar Temporizador (iTasks)"],
        "suite.ref.complete": [.es: "Completar última tarea (iTasks)", .en: "Complete last task (iTasks)", .pt: "Concluir última tarefa (iTasks)"],
        "suite.ref.today": [.es: "Escuchar tareas de hoy (iTasks)", .en: "Hear today's tasks (iTasks)", .pt: "Ouvir tarefas de hoje (iTasks)"],
        "suite.ref.screenshot": [.es: "Captura de pantalla (iCapture)", .en: "Screenshot (iCapture)", .pt: "Captura de tela (iCapture)"],
        "suite.ref.record": [.es: "Grabar pantalla (iCapture)", .en: "Record screen (iCapture)", .pt: "Gravar tela (iCapture)"],
        "suite.ref.ocr": [.es: "Copiar texto en pantalla (iCapture)", .en: "Copy on-screen text (iCapture)", .pt: "Copiar texto na tela (iCapture)"],
        "suite.ref.ask": [.es: "Preguntar a la IA (iBrain)", .en: "Ask the AI (iBrain)", .pt: "Perguntar à IA (iBrain)"],
        "suite.ref.clean": [.es: "Limpiar el Mac (iOrganize)", .en: "Clean the Mac (iOrganize)", .pt: "Limpar o Mac (iOrganize)"],
        "suite.ref.meeting": [.es: "Grabar reunión (MeetingAI)", .en: "Record meeting (MeetingAI)", .pt: "Gravar reunião (MeetingAI)"],

        // MARK: - Dictation flow
        "dictation.mic_permission_needed": [
            .es: "Se necesita permiso de micrófono — abrí Hikari Yaps",
            .en: "Microphone permission needed — open Hikari Yaps",
            .pt: "É necessária permissão de microfone — abra o Hikari Yaps",
        ],
        "dictation.no_speech_detected": [.es: "No se detectó nada", .en: "Didn't catch that", .pt: "Não foi possível entender"],
        "injector.secure_field": [
            .es: "Campo seguro — presioná ⌘V para pegar",
            .en: "Secure field — press ⌘V to paste",
            .pt: "Campo seguro — pressione ⌘V para colar",
        ],
        "injector.accessibility_needed": [
            .es: "Se necesita permiso de accesibilidad — otorgalo en Preferencias",
            .en: "Accessibility permission needed — grant it in Settings",
            .pt: "É necessária permissão de acessibilidade — conceda em Preferências",
        ],
        "injector.target_closed": [
            .es: "La app de destino se cerró — texto copiado al portapapeles",
            .en: "Target app closed — text copied to clipboard",
            .pt: "O app de destino foi fechado — texto copiado para a área de transferência",
        ],
        "injector.reactivate_failed": [
            .es: "No se pudo volver a la app de destino — presioná ⌘V para pegar",
            .en: "Couldn't switch back to the target app — press ⌘V to paste",
            .pt: "Não foi possível voltar ao app de destino — pressione ⌘V para colar",
        ],
    ]
}
