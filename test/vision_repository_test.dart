import 'dart:convert';
import 'dart:typed_data';

import 'package:esami_tracker/models/stato_valore.dart';
import 'package:esami_tracker/repositories/vision_repository.dart';
import 'package:esami_tracker/services/vision/lm_studio_client.dart';
import 'package:esami_tracker/services/vision/ollama_client.dart';
import 'package:esami_tracker/services/vision/vision_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

const _jsonValido =
    '{"data": "2024-03-15", "valori": [{"nome": "Glicemia", "valore": 92, '
    '"unita": "mg/dL", "range_min": 70, "range_max": 99}]}';

/// Client finto che registra le chiamate e risponde dalla coda.
class _FakeVisionClient implements VisionClient {
  final List<String> rispostePendenti;
  final List<({List<Uint8List> immagini, double temperatura})> chiamate = [];

  _FakeVisionClient(this.rispostePendenti);

  @override
  String get nomeBackend => 'Fake';

  @override
  Future<String> generaTesto({
    required String prompt,
    required List<Uint8List> immaginiPng,
    required double temperatura,
  }) async {
    expect(prompt, VisionRepository.promptEstrazione);
    chiamate.add((immagini: immaginiPng, temperatura: temperatura));
    return rispostePendenti.removeAt(0);
  }
}

void main() {
  group('LmStudioClient', () {
    test('manda la richiesta in formato OpenAI con immagini base64', () async {
      late http.Request richiesta;
      final client = LmStudioClient(
        endpoint: 'http://localhost:1234/v1',
        modello: 'qwen-test',
        httpClient: MockClient((req) async {
          richiesta = req;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': _jsonValido},
                },
              ],
            }),
            200,
          );
        }),
      );

      final testo = await client.generaTesto(
        prompt: 'prompt di prova',
        immaginiPng: [_png],
        temperatura: 0.2,
      );

      expect(testo, _jsonValido);
      expect(
        richiesta.url.toString(),
        'http://localhost:1234/v1/chat/completions',
      );

      final corpo = jsonDecode(richiesta.body) as Map<String, dynamic>;
      expect(corpo['model'], 'qwen-test');
      expect(corpo['temperature'], 0.2);
      final contenuto =
          ((corpo['messages'] as List).single
                  as Map<String, dynamic>)['content']
              as List;
      expect((contenuto[0] as Map)['text'], 'prompt di prova');
      final urlImmagine =
          ((contenuto[1] as Map)['image_url'] as Map)['url'] as String;
      expect(urlImmagine, startsWith('data:image/png;base64,'));
      expect(base64Decode(urlImmagine.split(',').last), _png);
    });

    test('HTTP non-200 → VisionClientException', () async {
      final client = LmStudioClient(
        endpoint: 'http://localhost:1234/v1',
        modello: 'm',
        httpClient: MockClient(
          (_) async => http.Response('model not loaded', 404),
        ),
      );

      await expectLater(
        client.generaTesto(prompt: 'p', immaginiPng: [_png], temperatura: 0),
        throwsA(
          isA<VisionClientException>().having(
            (e) => e.messaggio,
            'messaggio',
            contains('404'),
          ),
        ),
      );
    });

    test('endpoint irraggiungibile → VisionClientException parlante', () async {
      final client = LmStudioClient(
        endpoint: 'http://localhost:1234/v1',
        modello: 'm',
        httpClient: MockClient(
          (_) async => throw http.ClientException('connection refused'),
        ),
      );

      await expectLater(
        client.generaTesto(prompt: 'p', immaginiPng: [_png], temperatura: 0),
        throwsA(
          isA<VisionClientException>().having(
            (e) => e.messaggio,
            'messaggio',
            contains('LM Studio non raggiungibile'),
          ),
        ),
      );
    });

    test('risposta senza choices → VisionClientException', () async {
      final client = LmStudioClient(
        endpoint: 'http://localhost:1234/v1',
        modello: 'm',
        httpClient: MockClient(
          (_) async => http.Response('{"error": "boom"}', 200),
        ),
      );

      await expectLater(
        client.generaTesto(prompt: 'p', immaginiPng: [_png], temperatura: 0),
        throwsA(isA<VisionClientException>()),
      );
    });
  });

  group('OllamaClient', () {
    test('manda la richiesta in formato Ollama con campo images', () async {
      late http.Request richiesta;
      final client = OllamaClient(
        endpoint: 'http://localhost:11434/api',
        modello: 'qwen2.5vl:7b',
        httpClient: MockClient((req) async {
          richiesta = req;
          return http.Response(jsonEncode({'response': _jsonValido}), 200);
        }),
      );

      final testo = await client.generaTesto(
        prompt: 'prompt di prova',
        immaginiPng: [_png],
        temperatura: 0,
      );

      expect(testo, _jsonValido);
      expect(richiesta.url.toString(), 'http://localhost:11434/api/generate');

      final corpo = jsonDecode(richiesta.body) as Map<String, dynamic>;
      expect(corpo['model'], 'qwen2.5vl:7b');
      expect(corpo['prompt'], 'prompt di prova');
      expect(corpo['stream'], false);
      expect((corpo['options'] as Map)['temperature'], 0);
      expect(base64Decode((corpo['images'] as List).single as String), _png);
    });

    test('HTTP non-200 → VisionClientException', () async {
      final client = OllamaClient(
        endpoint: 'http://localhost:11434/api',
        modello: 'm',
        httpClient: MockClient(
          (_) async => http.Response('no such model', 500),
        ),
      );

      await expectLater(
        client.generaTesto(prompt: 'p', immaginiPng: [_png], temperatura: 0),
        throwsA(isA<VisionClientException>()),
      );
    });
  });

  group('VisionRepository.parseRisposta', () {
    test('JSON pulito con data ISO', () {
      final risultato = VisionRepository.parseRisposta(_jsonValido);
      expect(risultato.valori, hasLength(1));
      expect(risultato.valori.single.nome, 'Glicemia');
      expect(risultato.valori.single.valore, 92);
      expect(risultato.valori.single.unita, 'mg/dL');
      expect(risultato.valori.single.range.min, 70);
      expect(risultato.valori.single.range.max, 99);
      expect(risultato.valori.single.stato, StatoValore.inRange);
      expect(risultato.data, DateTime(2024, 3, 15));
    });

    test('data in formato DD/MM/YYYY', () {
      const risposta =
          '{"data": "15/03/2024", "valori": [{"nome": "Glucosio", '
          '"valore": 90, "unita": "mg/dL"}]}';
      final risultato = VisionRepository.parseRisposta(risposta);
      expect(risultato.data, DateTime(2024, 3, 15));
    });

    test('data in formato DD/MM/YY', () {
      const risposta =
          '{"data": "15/03/24", "valori": [{"nome": "Glucosio", '
          '"valore": 90, "unita": "mg/dL"}]}';
      final risultato = VisionRepository.parseRisposta(risposta);
      expect(risultato.data, DateTime(2024, 3, 15));
    });

    test('data in formato DD.MM.YYYY', () {
      const risposta =
          '{"data": "15.03.2024", "valori": [{"nome": "Glucosio", '
          '"valore": 90, "unita": "mg/dL"}]}';
      final risultato = VisionRepository.parseRisposta(risposta);
      expect(risultato.data, DateTime(2024, 3, 15));
    });

    test('data assente → null', () {
      const risposta =
          '{"valori": [{"nome": "Glucosio", "valore": 90, "unita": "mg/dL"}]}';
      final risultato = VisionRepository.parseRisposta(risposta);
      expect(risultato.data, isNull);
    });

    test('data futura → null (scartata)', () {
      const risposta =
          '{"data": "2099-01-01", "valori": [{"nome": "X", "valore": 1}]}';
      final risultato = VisionRepository.parseRisposta(risposta);
      expect(risultato.data, isNull);
    });

    test('JSON dentro code fence markdown e testo attorno', () {
      final risposta =
          'Ecco i valori estratti:\n```json\n$_jsonValido\n```\nSpero aiuti!';
      expect(VisionRepository.parseRisposta(risposta).valori, hasLength(1));
    });

    test('numeri come stringhe con la virgola', () {
      const risposta =
          '{"valori": [{"nome": "TSH", "valore": "2,1", "unita": "µUI/mL", '
          '"range_min": "0,4", "range_max": "4,0"}]}';
      final valore = VisionRepository.parseRisposta(risposta).valori.single;
      expect(valore.valore, 2.1);
      expect(valore.range.min, 0.4);
      expect(valore.range.max, 4.0);
    });

    test('range mancanti o null → range aperto/vuoto', () {
      const risposta =
          '{"valori": [{"nome": "HDL", "valore": 55, "unita": "mg/dL", '
          '"range_min": 40, "range_max": null}]}';
      final valore = VisionRepository.parseRisposta(risposta).valori.single;
      expect(valore.range.min, 40);
      expect(valore.range.max, isNull);
    });

    test('righe senza nome o senza valore numerico vengono scartate', () {
      const risposta =
          '{"valori": ['
          '{"nome": "Glicemia", "valore": 92, "unita": "mg/dL"}, '
          '{"nome": "", "valore": 1}, '
          '{"valore": 5}, '
          '{"nome": "Rotto", "valore": "n/d"}]}';
      final valori = VisionRepository.parseRisposta(risposta).valori;
      expect(valori.map((v) => v.nome), ['Glicemia']);
    });

    test('nessun JSON → FormatException', () {
      expect(
        () => VisionRepository.parseRisposta('Mi dispiace, non posso aiutarti'),
        throwsFormatException,
      );
    });

    test('JSON senza lista valori → FormatException', () {
      expect(
        () => VisionRepository.parseRisposta('{"risultato": "ok"}'),
        throwsFormatException,
      );
    });
  });

  group('VisionRepository.estraiValori', () {
    test('poche pagine → una sola richiesta con tutte le immagini', () async {
      final client = _FakeVisionClient([_jsonValido]);
      final repo = VisionRepository(client);
      final progressi = <(int, int)>[];

      final risultato = await repo.estraiValori([
        _png,
        _png,
      ], onProgresso: (p, t) => progressi.add((p, t)));

      expect(risultato.valori, hasLength(1));
      expect(risultato.data, DateTime(2024, 3, 15));
      expect(client.chiamate, hasLength(1));
      expect(client.chiamate.single.immagini, hasLength(2));
      expect(progressi, [(1, 1)]);
    });

    test('risposta non valida → retry a temperatura 0', () async {
      final client = _FakeVisionClient([
        'Mi dispiace, ecco una poesia sui globuli rossi',
        _jsonValido,
      ]);
      final repo = VisionRepository(client);

      final risultato = await repo.estraiValori([_png]);

      expect(risultato.valori, hasLength(1));
      expect(client.chiamate, hasLength(2));
      expect(client.chiamate.first.temperatura, greaterThan(0));
      expect(client.chiamate.last.temperatura, 0);
    });

    test(
      'JSON invalido anche al retry → EstrazioneNonValidaException',
      () async {
        final client = _FakeVisionClient(['non-json 1', 'non-json 2']);
        final repo = VisionRepository(client);

        await expectLater(
          repo.estraiValori([_png]),
          throwsA(
            isA<EstrazioneNonValidaException>().having(
              (e) => e.rispostaGrezza,
              'rispostaGrezza',
              'non-json 2',
            ),
          ),
        );
      },
    );

    test('errore di rete del client risale invariato', () async {
      final repo = VisionRepository(
        _ClientCheEsplode(const VisionClientException('endpoint giù')),
      );

      await expectLater(
        repo.estraiValori([_png]),
        throwsA(isA<VisionClientException>()),
      );
    });

    test(
      'referto lungo → una richiesta per pagina, unione senza duplicati, '
      'prima data vince',
      () async {
        const paginaGlicemia =
            '{"data": "2024-01-10", "valori": [{"nome": "Glicemia", '
            '"valore": 92, "unita": "mg/dL"}]}';
        const paginaMista =
            '{"data": "2024-01-11", "valori": [{"nome": "GLICEMIA", '
            '"valore": 92, "unita": "mg/dL"}, '
            '{"nome": "TSH", "valore": 2.1, "unita": "µUI/mL"}]}';
        const paginaVuota = '{"valori": []}';
        final client = _FakeVisionClient([
          paginaGlicemia,
          paginaMista,
          paginaVuota,
        ]);
        final repo = VisionRepository(client);
        final progressi = <(int, int)>[];

        final risultato = await repo.estraiValori([
          _png,
          _png,
          _png,
        ], onProgresso: (p, t) => progressi.add((p, t)));

        expect(client.chiamate, hasLength(3));
        expect(client.chiamate.every((c) => c.immagini.length == 1), isTrue);
        // "GLICEMIA" della seconda pagina è un duplicato case-insensitive.
        expect(risultato.valori.map((v) => v.nome), ['Glicemia', 'TSH']);
        // Prima data trovata (pagina 1) vince sulla seconda.
        expect(risultato.data, DateTime(2024, 1, 10));
        expect(progressi, [(1, 3), (2, 3), (3, 3)]);
      },
    );

    test('nessuna pagina → lista vuota senza chiamate', () async {
      final client = _FakeVisionClient([]);
      final repo = VisionRepository(client);

      final risultato = await repo.estraiValori([]);
      expect(risultato.valori, isEmpty);
      expect(risultato.data, isNull);
      expect(client.chiamate, isEmpty);
    });
  });
}

class _ClientCheEsplode implements VisionClient {
  final Object errore;

  _ClientCheEsplode(this.errore);

  @override
  String get nomeBackend => 'Esplosivo';

  @override
  Future<String> generaTesto({
    required String prompt,
    required List<Uint8List> immaginiPng,
    required double temperatura,
  }) async => throw errore;
}
