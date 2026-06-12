import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'vision_client.dart';

/// Client per LM Studio (o qualunque server OpenAI-compatible):
/// `POST {endpoint}/chat/completions` con le immagini in base64 dentro
/// il messaggio utente.
class LmStudioClient implements VisionClient {
  /// Base URL, es. `http://localhost:1234/v1`.
  final String endpoint;
  final String modello;
  final http.Client _http;
  final Duration timeout;

  LmStudioClient({
    required this.endpoint,
    required this.modello,
    http.Client? httpClient,
    // L'inferenza vision su hardware consumer può essere lenta.
    this.timeout = const Duration(minutes: 5),
  }) : _http = httpClient ?? http.Client();

  @override
  String get nomeBackend => 'LM Studio';

  @override
  Future<String> generaTesto({
    required String prompt,
    required List<Uint8List> immaginiPng,
    required double temperatura,
  }) async {
    final uri = Uri.parse('$endpoint/chat/completions');
    final corpo = jsonEncode({
      'model': modello,
      'temperature': temperatura,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            for (final png in immaginiPng)
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,${base64Encode(png)}',
                },
              },
          ],
        },
      ],
    });

    final http.Response risposta;
    try {
      risposta = await _http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: corpo)
          .timeout(timeout);
    } catch (e) {
      throw VisionClientException(
        'LM Studio non raggiungibile su $endpoint: è in esecuzione con il '
        'server attivo?',
        e,
      );
    }
    if (risposta.statusCode != 200) {
      throw VisionClientException(
        'LM Studio ha risposto HTTP ${risposta.statusCode}: '
        '${risposta.body}',
      );
    }

    try {
      final json = jsonDecode(risposta.body) as Map<String, dynamic>;
      final scelte = json['choices'] as List<dynamic>;
      final messaggio =
          (scelte.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      return messaggio['content'] as String;
    } catch (e) {
      throw VisionClientException('Risposta LM Studio in formato inatteso', e);
    }
  }
}
