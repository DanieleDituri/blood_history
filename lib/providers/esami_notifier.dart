import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/mock/mock_esami.dart';
import '../models/esame.dart';
import '../models/parametro_snapshot.dart';
import '../models/range_riferimento.dart';
import '../models/serie_parametro.dart';
import '../repositories/esame_repository.dart';
import 'providers.dart';

/// Notifier che gestisce la lista completa degli esami caricati in memoria.
///
/// È la fonte di verità da cui [snapshotProvider] e [graficiProvider]
/// derivano automaticamente i propri dati.
class EsamiNotifier extends AsyncNotifier<List<Esame>> {
  @override
  Future<List<Esame>> build() async {
    final repo = ref.watch(esameRepositoryProvider);
    final reali = await repo.esami();
    if (reali.isNotEmpty) return reali;
    return _esamiMock();
  }

  /// Ricarica dalla cache SQLite locale.
  Future<void> ricarica() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(esameRepositoryProvider).esami(),
    );
    if (state.value?.isEmpty ?? false) {
      state = AsyncData(await _esamiMock());
    }
  }

  /// Aggiunge un esame alla cache locale e aggiorna lo stato.
  Future<void> aggiungi(Esame esame) async {
    await ref.read(esameRepositoryProvider).salvaEsame(esame);
    ref.read(usaDatiMockProvider.notifier).state = false;
    await ricarica();
  }

  static Future<List<Esame>> _esamiMock() async {
    final db = AppDatabase.inMemory();
    try {
      final repo = EsameRepository(db);
      for (final e in MockEsami.esami) {
        await repo.salvaEsame(e);
      }
      return repo.esami();
    } finally {
      await db.close();
    }
  }
}

final esamiNotifierProvider =
    AsyncNotifierProvider<EsamiNotifier, List<Esame>>(EsamiNotifier.new);

// ---- Provider derivati -------------------------------------------------------

/// Ultimo valore noto di ogni parametro, per la griglia della Snapshot.
final snapshotProvider = FutureProvider<List<ParametroSnapshot>>((ref) async {
  final esami = await ref.watch(esamiNotifierProvider.future);
  final visti = <String>{};
  final risultato = <ParametroSnapshot>[];
  for (final esame in esami) {
    for (final valore in esame.valori) {
      if (visti.add(valore.nome.toLowerCase())) {
        risultato.add(
          ParametroSnapshot(valore: valore, dataEsame: esame.data),
        );
      }
    }
  }
  risultato.sort(
    (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
  );
  return risultato;
});

/// Serie temporali di tutti i parametri, per la schermata Grafici.
final graficiProvider = FutureProvider<List<SerieParametro>>((ref) async {
  final esami = await ref.watch(esamiNotifierProvider.future);
  return _calcolaSerieParametri(esami);
});

List<SerieParametro> _calcolaSerieParametri(List<Esame> esami) {
  final puntiMap = <String, List<PuntoParametro>>{};
  final unitaMap = <String, String>{};
  final rangeMap = <String, RangeRiferimento>{};
  final nomeOrig = <String, String>{};

  // Dal più vecchio al più recente: punti in ordine crescente.
  for (final esame in esami.reversed) {
    for (final valore in esame.valori) {
      final chiave = valore.nome.toLowerCase();
      puntiMap
          .putIfAbsent(chiave, () => [])
          .add(PuntoParametro(data: esame.data, valore: valore.valore));
      unitaMap[chiave] = valore.unita;
      rangeMap[chiave] = valore.range;
      nomeOrig[chiave] = valore.nome;
    }
  }

  return puntiMap.entries
      .map(
        (e) => SerieParametro(
          nome: nomeOrig[e.key]!,
          unita: unitaMap[e.key]!,
          range: rangeMap[e.key]!,
          punti: e.value,
        ),
      )
      .toList()
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
}
