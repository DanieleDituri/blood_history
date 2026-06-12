import '../data/db/database.dart';
import '../models/esame.dart';
import '../models/parametro_snapshot.dart';
import '../models/range_riferimento.dart';
import '../models/serie_parametro.dart';
import 'drive_repository.dart';

/// Esito di una sincronizzazione da Drive.
class RisultatoSync {
  final int scaricati;
  final int invariati;
  final List<String> errori;

  const RisultatoSync({
    this.scaricati = 0,
    this.invariati = 0,
    this.errori = const [],
  });

  bool get haErrori => errori.isNotEmpty;

  @override
  String toString() =>
      'RisultatoSync(scaricati: $scaricati, invariati: $invariati, '
      'errori: ${errori.length})';
}

/// Repository principale degli esami: legge dalla cache SQLite (drift) e
/// la mantiene allineata con Google Drive, che resta la fonte di verità.
class EsameRepository {
  final AppDatabase _db;
  final DriveRepository? _drive;

  EsameRepository(this._db, {DriveRepository? drive}) : _drive = drive;

  /// Tutti gli esami in cache, dal più recente.
  Future<List<Esame>> esami() => _db.tuttiGliEsami();

  Future<Esame?> esamePerData(String dataIso) => _db.esamePerData(dataIso);

  /// Salva un esame in cache (usato dopo l'import e dalla sync).
  Future<void> salvaEsame(Esame esame, {DateTime? modificatoIl}) =>
      _db.upsertEsame(esame, modificatoIl: modificatoIl);

  Future<void> eliminaEsame(String dataIso) => _db.eliminaEsame(dataIso);

  /// L'ultimo valore noto di ogni parametro, per la schermata Snapshot.
  ///
  /// I parametri sono confrontati per nome (case-insensitive) e ordinati
  /// alfabeticamente.
  Future<List<ParametroSnapshot>> snapshot() async {
    final tutti = await _db.tuttiGliEsami(); // già ordinati: recente → vecchio
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
  ///
  /// Il range è quello dell'esame più recente che contiene quel parametro.
  /// I punti sono ordinati dal più vecchio al più recente (per i grafici).
  Future<List<SerieParametro>> serieParametri() async {
    final tutti = await _db.tuttiGliEsami(); // recente → vecchio
    // Accumuliamo per chiave (nome lowercase) → punti in ordine inverso.
    final puntiPerParametro = <String, List<PuntoParametro>>{};
    final unitaPerParametro = <String, String>{};
    final rangePerParametro = <String, RangeRiferimento>{};
    final nomeOriginale = <String, String>{};

    // Iteriamo dal più vecchio al più recente per avere i punti in ordine.
    for (final esame in tutti.reversed) {
      for (final valore in esame.valori) {
        final chiave = valore.nome.toLowerCase();
        puntiPerParametro
            .putIfAbsent(chiave, () => [])
            .add(PuntoParametro(data: esame.data, valore: valore.valore));
        // L'esame più recente sovrascrive unità e range (iterazione avanti→indietro).
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

  /// Sincronizza la cache locale da Drive: scarica i JSON nuovi o
  /// modificati, salta quelli già aggiornati. Un errore su un singolo file
  /// non interrompe la sync degli altri.
  Future<RisultatoSync> syncDaDrive() async {
    final drive = _drive;
    if (drive == null) {
      throw StateError('Sync non disponibile: DriveRepository non configurato');
    }

    final remoti = await drive.listEsami();
    final dateLocali = await _db.dateModificaLocali();

    var scaricati = 0;
    var invariati = 0;
    final errori = <String>[];

    for (final remoto in remoti) {
      final localeModificatoIl = dateLocali[remoto.dataIso];
      final aggiornato =
          dateLocali.containsKey(remoto.dataIso) &&
          localeModificatoIl != null &&
          remoto.modificatoIl != null &&
          !remoto.modificatoIl!.isAfter(localeModificatoIl);
      if (aggiornato) {
        invariati++;
        continue;
      }
      try {
        final esame = await drive.downloadJson(remoto.jsonFileId);
        await _db.upsertEsame(esame, modificatoIl: remoto.modificatoIl);
        scaricati++;
      } catch (e) {
        errori.add('${remoto.dataIso}: $e');
      }
    }

    return RisultatoSync(
      scaricati: scaricati,
      invariati: invariati,
      errori: errori,
    );
  }
}
