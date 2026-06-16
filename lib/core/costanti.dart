/// Costanti condivise dell'app.
class Costanti {
  Costanti._();

  static const nomeApp = 'EsamiTracker';

  // Chiavi shared_preferences.
  static const prefEndpointModello = 'endpoint_modello';
  static const prefNomeModello = 'nome_modello';
  static const prefOnboardingCompletato = 'onboarding_completato';
  static const prefCartellaBackup = 'cartella_backup';

  // Android: modalità estrazione ('ocr' | 'llm' | null = non scelto)
  static const prefModalitaAndroid = 'android_modalita';
  static const prefHuggingFaceToken = 'hf_token';

  // Desktop (macOS/Windows/Linux): modalità estrazione
  static const prefModalitaDesktop = 'desktop_modalita';

  // MediaPipe Gemma 2B
  static const llmNomeFile = 'gemma-2b-it-cpu-int4.bin';
  static const llmUrlHuggingFace =
      'https://huggingface.co/google/gemma-2b-it-mediapipe'
      '/resolve/main/gemma-2b-it-cpu-int4.bin';

  // Modello vision locale.
  static const prefTipoModello = 'tipo_modello'; // 'lmstudio' | 'ollama'
  static const endpointLmStudio = 'http://localhost:1234/v1';
  static const endpointOllama = 'http://localhost:11434/api';
  static const modelloDefaultLmStudio = 'qwen/qwen3-vl-8b';
  static const modelloDefaultOllama = 'qwen3-vl:8b';
}
