import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/esame.dart';
import '../../models/range_riferimento.dart';
import '../../models/valore_esame.dart';

part 'database.g.dart';

/// Tabella degli esami: un record per referto, identificato dalla data
/// del prelievo in formato ISO `YYYY-MM-DD` (stessa chiave usata come nome
/// file su Drive).
class TabellaEsami extends Table {
  TextColumn get dataIso => text().withLength(min: 10, max: 10)();
  TextColumn get laboratorio => text().nullable()();
  TextColumn get jsonDriveId => text().nullable()();
  TextColumn get pdfDriveId => text().nullable()();

  /// modifiedTime del JSON su Drive: usato dalla sync per capire se il
  /// file remoto è cambiato rispetto alla copia in cache.
  DateTimeColumn get modificatoIl => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {dataIso};
}

/// Tabella dei singoli valori, in relazione 1-N con [TabellaEsami].
class TabellaValori extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get esameDataIso =>
      text().references(TabellaEsami, #dataIso, onDelete: KeyAction.cascade)();
  TextColumn get nome => text()();
  RealColumn get valore => real()();
  TextColumn get unita => text().withDefault(const Constant(''))();
  RealColumn get rangeMin => real().nullable()();
  RealColumn get rangeMax => real().nullable()();
}

@DriftDatabase(tables: [TabellaEsami, TabellaValori])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? _apriConnessione());

  /// Database volatile: usato dai test e dai dati mock.
  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _apriConnessione() =>
      driftDatabase(name: 'esami_tracker');

  // ---- Letture ------------------------------------------------------------

  /// Tutti gli esami in cache, con i loro valori, dal più recente.
  Future<List<Esame>> tuttiGliEsami() async {
    final righeEsami = await (select(
      tabellaEsami,
    )..orderBy([(e) => OrderingTerm.desc(e.dataIso)])).get();
    if (righeEsami.isEmpty) return const [];

    final righeValori = await select(tabellaValori).get();
    final valoriPerEsame = <String, List<ValoreEsame>>{};
    for (final riga in righeValori) {
      valoriPerEsame
          .putIfAbsent(riga.esameDataIso, () => [])
          .add(_valoreDaRiga(riga));
    }

    return righeEsami
        .map((riga) => _esameDaRiga(riga, valoriPerEsame[riga.dataIso] ?? []))
        .toList();
  }

  Future<Esame?> esamePerData(String dataIso) async {
    final riga = await (select(
      tabellaEsami,
    )..where((e) => e.dataIso.equals(dataIso))).getSingleOrNull();
    if (riga == null) return null;
    final valori = await (select(
      tabellaValori,
    )..where((v) => v.esameDataIso.equals(dataIso))).get();
    return _esameDaRiga(riga, valori.map(_valoreDaRiga).toList());
  }

  /// Mappa dataIso → modifiedTime per il confronto con Drive in fase di sync.
  Future<Map<String, DateTime?>> dateModificaLocali() async {
    final righe = await select(tabellaEsami).get();
    return {for (final r in righe) r.dataIso: r.modificatoIl};
  }

  // ---- Scritture ----------------------------------------------------------

  /// Inserisce o sostituisce un esame con tutti i suoi valori, in modo
  /// atomico (i valori precedenti vengono rimpiazzati).
  Future<void> upsertEsame(Esame esame, {DateTime? modificatoIl}) {
    return transaction(() async {
      await into(tabellaEsami).insertOnConflictUpdate(
        TabellaEsamiCompanion.insert(
          dataIso: esame.dataIso,
          laboratorio: Value(esame.laboratorio),
          jsonDriveId: Value(esame.jsonDriveId),
          pdfDriveId: Value(esame.pdfDriveId),
          modificatoIl: Value(modificatoIl),
        ),
      );
      await (delete(
        tabellaValori,
      )..where((v) => v.esameDataIso.equals(esame.dataIso))).go();
      await batch((b) {
        b.insertAll(tabellaValori, [
          for (final v in esame.valori)
            TabellaValoriCompanion.insert(
              esameDataIso: esame.dataIso,
              nome: v.nome,
              valore: v.valore,
              unita: Value(v.unita),
              rangeMin: Value(v.range.min),
              rangeMax: Value(v.range.max),
            ),
        ]);
      });
    });
  }

  Future<void> eliminaEsame(String dataIso) =>
      (delete(tabellaEsami)..where((e) => e.dataIso.equals(dataIso))).go();

  // ---- Mapping riga → modello ----------------------------------------------

  static Esame _esameDaRiga(TabellaEsamiData riga, List<ValoreEsame> valori) =>
      Esame(
        data: DateTime.parse(riga.dataIso),
        valori: valori,
        laboratorio: riga.laboratorio,
        jsonDriveId: riga.jsonDriveId,
        pdfDriveId: riga.pdfDriveId,
      );

  static ValoreEsame _valoreDaRiga(TabellaValoriData riga) => ValoreEsame(
    nome: riga.nome,
    valore: riga.valore,
    unita: riga.unita,
    range: RangeRiferimento(min: riga.rangeMin, max: riga.rangeMax),
  );
}
