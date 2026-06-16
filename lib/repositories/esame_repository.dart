import '../data/db/database.dart';
import '../models/esame.dart';
import '../models/parametro_snapshot.dart';
import '../models/range_riferimento.dart';
import '../models/serie_parametro.dart';

/// Repository principale degli esami: legge e scrive sulla cache SQLite (drift).
class EsameRepository {
  final AppDatabase _db;

  EsameRepository(this._db);

  Future<List<Esame>> esami() => _db.tuttiGliEsami();

  Future<Esame?> esamePerData(String dataIso) => _db.esamePerData(dataIso);

  Future<void> salvaEsame(Esame esame, {DateTime? modificatoIl}) =>
      _db.upsertEsame(esame, modificatoIl: modificatoIl);

  Future<void> eliminaEsame(String dataIso) => _db.eliminaEsame(dataIso);

  /// L'ultimo valore noto di ogni parametro, per la schermata Snapshot.
  Future<List<ParametroSnapshot>> snapshot() async {
    final tutti = await _db.tuttiGliEsami();
    final visti = <String>{};
    final risultato = <ParametroSnapshot>[];
    for (final esame in tutti) {
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
  }

  /// Tutti i valori nel tempo di ogni parametro, per la schermata Grafici.
  Future<List<SerieParametro>> serieParametri() async {
    final tutti = await _db.tuttiGliEsami();
    final puntiPerParametro = <String, List<PuntoParametro>>{};
    final unitaPerParametro = <String, String>{};
    final rangePerParametro = <String, RangeRiferimento>{};
    final nomeOriginale = <String, String>{};

    for (final esame in tutti.reversed) {
      for (final valore in esame.valori) {
        final chiave = valore.nome.toLowerCase();
        puntiPerParametro
            .putIfAbsent(chiave, () => [])
            .add(PuntoParametro(data: esame.data, valore: valore.valore));
        unitaPerParametro[chiave] = valore.unita;
        rangePerParametro[chiave] = valore.range;
        nomeOriginale[chiave] = valore.nome;
      }
    }

    final serie = puntiPerParametro.entries
        .map(
          (e) => SerieParametro(
            nome: nomeOriginale[e.key]!,
            unita: unitaPerParametro[e.key]!,
            range: rangePerParametro[e.key]!,
            punti: e.value,
          ),
        )
        .toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    return serie;
  }
}
