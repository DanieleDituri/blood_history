/// Test di integrazione end-to-end:
///
///   Import PDF mock → estrazione valori (FakeVisionClient) →
///   salvataggio su DB locale → verifica Snapshot → verifica Grafici
///
/// Non richiede dispositivi fisici né Drive reale: tutto viene mockato.
library;

import 'dart:typed_data';

import 'package:esami_tracker/data/db/database.dart';
import 'package:esami_tracker/models/esame.dart';
import 'package:esami_tracker/models/range_riferimento.dart';
import 'package:esami_tracker/models/valore_esame.dart';
import 'package:esami_tracker/repositories/esame_repository.dart';
import 'package:esami_tracker/repositories/vision_repository.dart';
import 'package:esami_tracker/services/vision/vision_client.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Fake VisionClient -------------------------------------------------------

/// Risponde con un JSON predefinito che simula l'output del modello vision.
class _FakeVisionClient implements VisionClient {
  final String _risposta;

  const _FakeVisionClient(this._risposta);

  @override
  String get nomeBackend => 'FakeE2E';

  @override
  Future<String> generaTesto({
    required String prompt,
    required List<Uint8List> immaginiPng,
    required double temperatura,
  }) async => _risposta;
}

// ---- Helper per creare ValoreEsame ------------------------------------------

ValoreEsame _valoreGlicemia(double v) => ValoreEsame(
  nome: 'Glicemia',
  valore: v,
  unita: 'mg/dL',
  range: const RangeRiferimento(min: 70, max: 99),
);

ValoreEsame _valoreColesterolo(double v) => ValoreEsame(
  nome: 'Colesterolo',
  valore: v,
  unita: 'mg/dL',
  range: const RangeRiferimento(max: 200),
);

// ---- Test suite -------------------------------------------------------------

void main() {
  late AppDatabase db;
  late EsameRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = EsameRepository(db); // nessun Drive: solo cache locale
  });

  tearDown(() => db.close());

  // --- Flusso completo -------------------------------------------------------

  test('E2E: estrazione PDF mock → salvataggio → snapshot → grafici', () async {
    // 1. JSON che simula l'output del modello vision su un referto
    const jsonReferto = '''
    {
      "data": "2026-03-15",
      "laboratorio": "Lab Test S.r.l.",
      "valori": [
        {"nome": "Glicemia",    "valore": 92.0,  "unita": "mg/dL",
         "range_min": 70.0, "range_max": 99.0},
        {"nome": "Colesterolo", "valore": 185.0, "unita": "mg/dL",
         "range_min": null,  "range_max": 200.0},
        {"nome": "Emoglobina",  "valore": 14.2,  "unita": "g/dL",
         "range_min": 12.0, "range_max": 16.0}
      ]
    }
    ''';

    // 2. Estrazione tramite VisionRepository (fake client)
    final vision = VisionRepository(_FakeVisionClient(jsonReferto));
    final immaginiMock = [Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])];
    final risultato = await vision.estraiValori(immaginiMock);

    expect(risultato.valori, hasLength(3));
    expect(risultato.data, equals(DateTime(2026, 3, 15)));
    expect(risultato.valori.first.nome, equals('Glicemia'));

    // 3. Salvataggio in cache locale
    final esame = Esame(
      data: risultato.data!,
      valori: risultato.valori,
      laboratorio: 'Lab Test S.r.l.',
    );
    await repo.salvaEsame(esame);

    // 4. Verifica Snapshot (ultimo valore di ogni parametro)
    final snapshot = await repo.snapshot();

    expect(snapshot, hasLength(3));
    final nomiSnapshot = snapshot.map((p) => p.nome).toSet();
    expect(nomiSnapshot, containsAll(['Glicemia', 'Colesterolo', 'Emoglobina']));

    // Glicemia 92 è in range [70, 99]
    final glicemia = snapshot.firstWhere((p) => p.nome == 'Glicemia');
    expect(glicemia.valore.stato.name, anyOf('inRange', 'borderline'));

    // 5. Verifica Grafici (serie temporali)
    final serie = await repo.serieParametri();

    expect(serie, hasLength(3));
    final serieGlicemia = serie.firstWhere((s) => s.nome == 'Glicemia');
    expect(serieGlicemia.punti, hasLength(1));
    expect(serieGlicemia.punti.first.valore, equals(92.0));
    expect(serieGlicemia.unita, equals('mg/dL'));
    expect(serieGlicemia.range.min, equals(70.0));
    expect(serieGlicemia.range.max, equals(99.0));
  });

  // --- Import multipli → grafici con 2 punti ----------------------------------

  test('E2E: due esami storici → grafici mostrano 2 punti per parametro', () async {
    final esame1 = Esame(
      data: DateTime(2025, 6, 1),
      valori: [_valoreGlicemia(95.0), _valoreColesterolo(190.0)],
    );
    final esame2 = Esame(
      data: DateTime(2026, 3, 15),
      valori: [_valoreGlicemia(88.0), _valoreColesterolo(175.0)],
    );

    await repo.salvaEsame(esame1);
    await repo.salvaEsame(esame2);

    final serie = await repo.serieParametri();
    expect(serie, hasLength(2));

    final glicemia = serie.firstWhere((s) => s.nome == 'Glicemia');
    expect(glicemia.punti, hasLength(2));
    // Dal più vecchio al più recente
    expect(glicemia.punti.first.valore, equals(95.0));
    expect(glicemia.punti.last.valore, equals(88.0));

    // Snapshot mostra solo l'ultimo valore (esame più recente)
    final snapshot = await repo.snapshot();
    final snapGlicemia = snapshot.firstWhere((p) => p.nome == 'Glicemia');
    expect(snapGlicemia.valore.valore, equals(88.0));
  });

  // --- Ordinamento decrescente -------------------------------------------------

  test('EsameRepository.esami() restituisce esami in ordine data decrescente',
      () async {
    final date = [
      DateTime(2024, 1, 1),
      DateTime(2025, 6, 15),
      DateTime(2026, 3, 1),
    ];
    for (final d in date) {
      await repo.salvaEsame(
        Esame(data: d, valori: [_valoreGlicemia(90)]),
      );
    }

    final esami = await repo.esami();
    expect(esami, hasLength(3));
    // Più recente per primo
    expect(esami.first.data, equals(DateTime(2026, 3, 1)));
    expect(esami.last.data, equals(DateTime(2024, 1, 1)));
  });

  // --- Parsing JSON tollerante -------------------------------------------------

  test('VisionRepository.parseRisposta accetta JSON con testo attorno', () {
    const risposta = '''
    Ecco il JSON estratto dal referto:
    ```json
    {"data":"2026-05-10","valori":[
      {"nome":"TSH","valore":2.5,"unita":"mUI/L","range_min":0.4,"range_max":4.0}
    ]}
    ```
    Spero sia utile!
    ''';

    final risultato = VisionRepository.parseRisposta(risposta);
    expect(risultato.valori, hasLength(1));
    expect(risultato.valori.first.nome, equals('TSH'));
    expect(risultato.valori.first.valore, equals(2.5));
    expect(risultato.data, equals(DateTime(2026, 5, 10)));
  });
}
