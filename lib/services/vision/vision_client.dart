import 'dart:typed_data';

/// Errore di comunicazione con il modello vision locale (endpoint giù,
/// modello non caricato, HTTP non-200…).
class VisionClientException implements Exception {
  final String messaggio;
  final Object? causa;

  const VisionClientException(this.messaggio, [this.causa]);

  @override
  String toString() =>
      'VisionClientException: $messaggio${causa != null ? ' ($causa)' : ''}';
}

/// Client verso un modello vision locale: manda prompt + immagini e
/// restituisce il testo generato, senza interpretarlo.
///
/// Implementazioni: [LmStudioClient] (API OpenAI-compatible) e
/// [OllamaClient] (API nativa Ollama).
abstract class VisionClient {
  /// Nome leggibile del backend, per messaggi di errore in UI.
  String get nomeBackend;

  Future<String> generaTesto({
    required String prompt,
    required List<Uint8List> immaginiPng,
    required double temperatura,
  });
}
