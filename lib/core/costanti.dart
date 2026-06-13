/// Costanti condivise dell'app.
class Costanti {
  Costanti._();

  static const nomeApp = 'EsamiTracker';

  // Struttura cartelle su Google Drive.
  static const cartellaDrive = 'Esami del Sangue';
  static const sottocartellaPdf = 'pdf';
  static const sottocartellaData = 'data';
  static const sottocartellaExport = 'export';

  // Chiavi shared_preferences.
  static const prefEndpointModello = 'endpoint_modello';
  static const prefNomeModello = 'nome_modello';
  static const prefDriveClientId = 'drive_client_id';
  static const prefDriveClientSecret = 'drive_client_secret';
  static const prefCredenzialiDrive = 'drive_credentials';
  static const prefOnboardingCompletato = 'onboarding_completato';

  // Android: modalità estrazione ('ocr' | 'llm' | null = non scelto)
  static const prefModalitaAndroid = 'android_modalita';
  static const prefHuggingFaceToken = 'hf_token';

  // Desktop (macOS/Windows/Linux): modalità estrazione
  // 'vision' = rasterizza PDF → modello vision (default)
  // 'ocr'    = estrae testo dal PDF → LLM testuale (nessun vision model necessario)
  static const prefModalitaDesktop = 'desktop_modalita';

  // MediaPipe Gemma 2B — modello consigliato per referti su dispositivo
  static const llmNomeFile = 'gemma-2b-it-cpu-int4.bin';
  static const llmUrlHuggingFace =
      'https://huggingface.co/google/gemma-2b-it-mediapipe'
      '/resolve/main/gemma-2b-it-cpu-int4.bin';

  // Modello vision locale.
  static const prefTipoModello = 'tipo_modello'; // 'lmstudio' | 'ollama'
  static const endpointLmStudio = 'http://localhost:1234/v1';
  static const endpointOllama = 'http://localhost:11434/api';
  // Qwen3-VL 8B: miglior rapporto qualità/velocità per OCR di referti
  // tra i modelli vision locali (MLX 4-bit consigliato su Mac).
  static const modelloDefaultLmStudio = 'qwen/qwen3-vl-8b';
  static const modelloDefaultOllama = 'qwen3-vl:8b';
}
