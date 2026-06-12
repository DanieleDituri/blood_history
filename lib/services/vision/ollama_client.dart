import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'vision_client.dart';

/// Client per Ollama: `POST {endpoint}/generate` con le immagini in
/// base64 nel campo `images`.
class OllamaClient implements VisionClient {
  /// Base URL, es. `http://localhost:11434/api`.
  final String endpoint;
  final String modello;
  final http.Client _http;
  final Duration timeout;

  OllamaClient({
    required this.endpoint,
    required this.modello,
    http.Client? httpClient,
    this.timeout = const Duration(minutes: 5),
  }) : _http = httpClient ?? http.Client();

  @override
  String get nomeBackend => 'Ollama';

  @override
  Future<String> generaTesto({
    required String prompt,
    required List<Uint8List> immaginiPng,
    required double temperatura,
  }) async {
    final uri = Uri.parse('$endpoint/generate');
    final corpo = jsonEncode({
      'model': modello,
      'prompt': prompt,
      'images': [for (final png in immaginiPng) base64Encode(png)],
      'stream': false,
      'options': {'temperature': temperatura},
    });

    final http.Response risposta;
    try {
      risposta = await _http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: corpo)
          .timeout(timeout);
    } catch (e) {
      throw VisionClientException(
        'Ollama non raggiungibile su $endpoint: è in esecuzione?',
        e,
      );
    }
    if (risposta.statusCode != 200) {
      throw VisionClientException(
        'Ollama ha risposto HTTP ${risposta.statusCode}: ${risposta.body}',
      );
    }

    try {
      final json = jsonDecode(risposta.body) as Map<String, dynamic>;
      return json['response'] as String;
    } catch (e) {
      throw VisionClientException('Risposta Ollama in formato inatteso', e);
    }
  }
}
