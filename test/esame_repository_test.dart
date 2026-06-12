import 'package:esami_tracker/data/db/database.dart';
import 'package:esami_tracker/models/esame.dart';
import 'package:esami_tracker/models/range_riferimento.dart';
import 'package:esami_tracker/models/valore_esame.dart';
import 'package:esami_tracker/repositories/drive_repository.dart';
import 'package:esami_tracker/repositories/esame_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDriveRepository extends Mock implements DriveRepository {}

Esame _esame(DateTime data, Map<String, double> valori) => Esame(
  data: data,
  valori: [
    for (final e in valori.entries)
      ValoreEsame(
        nome: e.key,
        valore: e.value,
        unita: 'mg/dL',
        range: const RangeRiferimento(min: 70, max: 99),
      ),
  ],
);

void main() {
  late AppDatabase db;
  late EsameRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = EsameRepository(db);
  });

  tearDown(() => db.close());

  group('cache drift', () {
    test('salva e rilegge un esame con i suoi valori', () async {
      await repo.salvaEsame(_esame(DateTime(2026, 5, 12), {'Glicemia': 92}));

      final esami = await repo.esami();
      expect(esami, hasLength(1));
      expect(esami.first.dataIso, '2026-05-12');
      expect(esami.first.valori.single.nome, 'Glicemia');
      expect(
        esami.first.valori.single.range,
        const RangeRiferimento(min: 70, max: 99),
      );
    });

    test('gli esami sono ordinati dal più recente', () async {
      await repo.salvaEsame(_esame(DateTime(2025, 11, 3), {'Glicemia': 90}));
      await repo.salvaEsame(_esame(DateTime(2026, 5, 12), {'Glicemia': 92}));
      await repo.salvaEsame(_esame(DateTime(2026, 2, 10), {'Glicemia': 95}));

      final esami = await repo.esami();
      expect(esami.map((e) => e.dataIso), [
        '2026-05-12',
        '2026-02-10',
        '2025-11-03',
      ]);
    });

    test('upsert sulla stessa data sostituisce i valori', () async {
      final data = DateTime(2026, 5, 12);
      await repo.salvaEsame(_esame(data, {'Glicemia': 92, 'TSH': 2}));
      await repo.salvaEsame(_esame(data, {'Glicemia': 95}));

      final esame = await repo.esamePerData('2026-05-12');
      expect(esame!.valori, hasLength(1));
      expect(esame.valori.single.valore, 95);
    });

    test('eliminaEsame rimuove anche i valori (cascade)', () async {
      await repo.salvaEsame(_esame(DateTime(2026, 5, 12), {'Glicemia': 92}));
      await repo.eliminaEsame('2026-05-12');

      expect(await repo.esami(), isEmpty);
      expect(await db.select(db.tabellaValori).get(), isEmpty);
    });
  });

  group('snapshot', () {
    test('prende l\'ultimo valore di ogni parametro', () async {
      await repo.salvaEsame(
        _esame(DateTime(2026, 2, 10), {'Glicemia': 96, 'Ferritina': 72}),
      );
      await repo.salvaEsame(_esame(DateTime(2026, 5, 12), {'Glicemia': 101}));

      final snapshot = await repo.snapshot();
      expect(snapshot, hasLength(2));

      final glicemia = snapshot.firstWhere((p) => p.nome == 'Glicemia');
      expect(glicemia.valore.valore, 101); // dal referto più recente
      expect(glicemia.dataEsame, DateTime(2026, 5, 12));

      final ferritina = snapshot.firstWhere((p) => p.nome == 'Ferritina');
      expect(ferritina.dataEsame, DateTime(2026, 2, 10));
    });

    test('confronta i nomi ignorando maiuscole/minuscole', () async {
      await repo.salvaEsame(_esame(DateTime(2026, 2, 10), {'glicemia': 96}));
      await repo.salvaEsame(_esame(DateTime(2026, 5, 12), {'Glicemia': 92}));

      final snapshot = await repo.snapshot();
      expect(snapshot, hasLength(1));
      expect(snapshot.single.valore.valore, 92);
    });
  });

  group('syncDaDrive', () {
    late _MockDriveRepository drive;

    setUp(() {
      drive = _MockDriveRepository();
      repo = EsameRepository(db, drive: drive);
    });

    test('scarica gli esami nuovi e li mette in cache', () async {
      final modifica = DateTime.utc(2026, 5, 13, 8);
      when(() => drive.listEsami()).thenAnswer(
        (_) async => [
          EsameRemoto(
            dataIso: '2026-05-12',
            jsonFileId: 'file-1',
            modificatoIl: modifica,
          ),
        ],
      );
      when(() => drive.downloadJson('file-1')).thenAnswer(
        (_) async => _esame(DateTime(2026, 5, 12), {'Glicemia': 92}),
      );

      final risultato = await repo.syncDaDrive();

      expect(risultato.scaricati, 1);
      expect(risultato.invariati, 0);
      expect(risultato.haErrori, isFalse);
      expect(await repo.esamePerData('2026-05-12'), isNotNull);
    });

    test('salta gli esami già aggiornati in cache', () async {
      final modifica = DateTime.utc(2026, 5, 13, 8);
      when(() => drive.listEsami()).thenAnswer(
        (_) async => [
          EsameRemoto(
            dataIso: '2026-05-12',
            jsonFileId: 'file-1',
            modificatoIl: modifica,
          ),
        ],
      );
      await repo.salvaEsame(
        _esame(DateTime(2026, 5, 12), {'Glicemia': 92}),
        modificatoIl: modifica,
      );

      final risultato = await repo.syncDaDrive();

      expect(risultato.scaricati, 0);
      expect(risultato.invariati, 1);
      verifyNever(() => drive.downloadJson(any()));
    });

    test('riscarica se il file remoto è più recente della cache', () async {
      when(() => drive.listEsami()).thenAnswer(
        (_) async => [
          EsameRemoto(
            dataIso: '2026-05-12',
            jsonFileId: 'file-1',
            modificatoIl: DateTime.utc(2026, 5, 14),
          ),
        ],
      );
      when(() => drive.downloadJson('file-1')).thenAnswer(
        (_) async => _esame(DateTime(2026, 5, 12), {'Glicemia': 101}),
      );
      await repo.salvaEsame(
        _esame(DateTime(2026, 5, 12), {'Glicemia': 92}),
        modificatoIl: DateTime.utc(2026, 5, 13),
      );

      final risultato = await repo.syncDaDrive();

      expect(risultato.scaricati, 1);
      final esame = await repo.esamePerData('2026-05-12');
      expect(esame!.valori.single.valore, 101);
    });

    test('un errore su un file non blocca la sync degli altri', () async {
      when(() => drive.listEsami()).thenAnswer(
        (_) async => [
          const EsameRemoto(dataIso: '2026-05-12', jsonFileId: 'rotto'),
          const EsameRemoto(dataIso: '2026-02-10', jsonFileId: 'ok'),
        ],
      );
      when(
        () => drive.downloadJson('rotto'),
      ).thenThrow(const DriveRepositoryException('JSON non valido'));
      when(() => drive.downloadJson('ok')).thenAnswer(
        (_) async => _esame(DateTime(2026, 2, 10), {'Glicemia': 96}),
      );

      final risultato = await repo.syncDaDrive();

      expect(risultato.scaricati, 1);
      expect(risultato.errori, hasLength(1));
      expect(risultato.errori.single, contains('2026-05-12'));
      expect(await repo.esamePerData('2026-02-10'), isNotNull);
    });

    test('senza DriveRepository configurato lancia StateError', () {
      expect(EsameRepository(db).syncDaDrive, throwsStateError);
    });
  });
}
