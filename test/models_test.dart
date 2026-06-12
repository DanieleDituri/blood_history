import 'package:esami_tracker/models/esame.dart';
import 'package:esami_tracker/models/range_riferimento.dart';
import 'package:esami_tracker/models/stato_valore.dart';
import 'package:esami_tracker/models/valore_esame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RangeRiferimento.statoDi', () {
    // Range 70–99: ampiezza 29, tolleranza borderline 2.9.
    const range = RangeRiferimento(min: 70, max: 99);

    test('valore dentro il range → inRange', () {
      expect(range.statoDi(85), StatoValore.inRange);
      expect(range.statoDi(70), StatoValore.inRange);
      expect(range.statoDi(99), StatoValore.inRange);
    });

    test('appena sopra il massimo (entro il 10%) → borderline', () {
      expect(range.statoDi(100), StatoValore.borderline);
      expect(range.statoDi(101.9), StatoValore.borderline);
    });

    test('appena sotto il minimo (entro il 10%) → borderline', () {
      expect(range.statoDi(68), StatoValore.borderline);
      expect(range.statoDi(67.1), StatoValore.borderline);
    });

    test('oltre la tolleranza del 10% → fuoriRange', () {
      expect(range.statoDi(102), StatoValore.fuoriRange);
      expect(range.statoDi(67), StatoValore.fuoriRange);
      expect(range.statoDi(150), StatoValore.fuoriRange);
    });

    test('range aperto solo massimo (es. colesterolo < 200)', () {
      const soloMax = RangeRiferimento(max: 200); // tolleranza 20
      expect(soloMax.statoDi(150), StatoValore.inRange);
      expect(soloMax.statoDi(215), StatoValore.borderline);
      expect(soloMax.statoDi(221), StatoValore.fuoriRange);
    });

    test('range aperto solo minimo (es. HDL > 40)', () {
      const soloMin = RangeRiferimento(min: 40); // tolleranza 4
      expect(soloMin.statoDi(55), StatoValore.inRange);
      expect(soloMin.statoDi(37), StatoValore.borderline);
      expect(soloMin.statoDi(35), StatoValore.fuoriRange);
    });

    test('senza range → sconosciuto', () {
      expect(const RangeRiferimento().statoDi(42), StatoValore.sconosciuto);
    });
  });

  group('RangeRiferimento.descrizione', () {
    test('formatta i vari tipi di range', () {
      expect(const RangeRiferimento(min: 70, max: 99).descrizione, '70 – 99');
      expect(const RangeRiferimento(max: 200).descrizione, '< 200');
      expect(const RangeRiferimento(min: 40).descrizione, '> 40');
      expect(const RangeRiferimento().descrizione, '—');
      expect(const RangeRiferimento(min: 0.4, max: 4).descrizione, '0.4 – 4');
    });
  });

  group('ValoreEsame JSON', () {
    test('roundtrip toJson/fromJson', () {
      const valore = ValoreEsame(
        nome: 'Glicemia',
        valore: 92.5,
        unita: 'mg/dL',
        range: RangeRiferimento(min: 70, max: 99),
      );
      expect(ValoreEsame.fromJson(valore.toJson()), valore);
    });

    test('fromJson tollera unita e range mancanti', () {
      final valore = ValoreEsame.fromJson({'nome': 'TSH', 'valore': 2});
      expect(valore.valore, 2.0);
      expect(valore.unita, '');
      expect(valore.stato, StatoValore.sconosciuto);
    });

    test('toJson usa le chiavi piatte range_min/range_max', () {
      const valore = ValoreEsame(
        nome: 'HDL',
        valore: 55,
        unita: 'mg/dL',
        range: RangeRiferimento(min: 40),
      );
      final json = valore.toJson();
      expect(json['range_min'], 40);
      expect(json['range_max'], isNull);
    });
  });

  group('Esame', () {
    final esame = Esame(
      data: DateTime(2026, 5, 12, 14, 30), // l'ora viene troncata
      laboratorio: 'Lab Test',
      valori: const [
        ValoreEsame(
          nome: 'Glicemia',
          valore: 92,
          unita: 'mg/dL',
          range: RangeRiferimento(min: 70, max: 99),
        ),
      ],
    );

    test('dataIso e nome file canonico YYYY-MM-DD.json', () {
      expect(esame.dataIso, '2026-05-12');
      expect(esame.nomeFileJson, '2026-05-12.json');
      expect(
        Esame(data: DateTime(2026, 1, 3), valori: const []).nomeFileJson,
        '2026-01-03.json',
      );
    });

    test('roundtrip toJson/fromJson', () {
      final ricostruito = Esame.fromJson(esame.toJson());
      expect(ricostruito.dataIso, esame.dataIso);
      expect(ricostruito.laboratorio, esame.laboratorio);
      expect(ricostruito.valori, esame.valori);
    });

    test('valorePerNome è case-insensitive', () {
      expect(esame.valorePerNome('glicemia'), isNotNull);
      expect(esame.valorePerNome('GLICEMIA')!.valore, 92);
      expect(esame.valorePerNome('Ferritina'), isNull);
    });
  });
}
