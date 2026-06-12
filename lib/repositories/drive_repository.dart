import 'dart:convert';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;

import '../core/costanti.dart';
import '../models/esame.dart';
import '../services/auth/drive_auth_service.dart';

/// Errore di I/O verso Google Drive.
class DriveRepositoryException implements Exception {
  final String messaggio;
  final Object? causa;

  const DriveRepositoryException(this.messaggio, [this.causa]);

  @override
  String toString() =>
      'DriveRepositoryException: $messaggio${causa != null ? ' ($causa)' : ''}';
}

/// Riferimento a un esame presente su Drive (senza i valori, che vanno
/// scaricati con [DriveRepository.downloadJson]).
class EsameRemoto {
  /// Data del prelievo in formato `YYYY-MM-DD`, derivata dal nome file.
  final String dataIso;
  final String jsonFileId;
  final DateTime? modificatoIl;

  const EsameRemoto({
    required this.dataIso,
    required this.jsonFileId,
    this.modificatoIl,
  });

  @override
  String toString() => 'EsameRemoto($dataIso, $jsonFileId)';
}

/// Accesso alla cartella `Esami del Sangue` su Google Drive:
///
/// ```
/// Esami del Sangue/
///   pdf/   ← referti originali
///   data/  ← un JSON per esame, nome YYYY-MM-DD.json
/// ```
///
/// Le cartelle vengono create al primo uso. L'upload di un JSON con data
/// già presente sovrascrive il file esistente (l'esame è identificato
/// dalla data).
class DriveRepository {
  static final _nomeFileJsonRegex = RegExp(r'^\d{4}-\d{2}-\d{2}\.json$');

  final DriveAuthService _auth;

  /// Factory per le API Drive, iniettabile nei test.
  final drive.DriveApi Function(dynamic client) _apiFactory;

  // Cache degli ID cartella per evitare una ricerca a ogni chiamata.
  String? _idCartellaRadice;
  String? _idCartellaPdf;
  String? _idCartellaData;

  DriveRepository(
    this._auth, {
    drive.DriveApi Function(dynamic client)? apiFactory,
  }) : _apiFactory = apiFactory ?? ((client) => drive.DriveApi(client));

  Future<drive.DriveApi> _api() async =>
      _apiFactory(await _auth.clientAutenticato());

  /// Email dell'account Google a cui è collegata l'app (per mostrare
  /// nelle Impostazioni "Drive collegato come …"). Null se l'API non
  /// la espone.
  Future<String?> emailAccount() async {
    final api = await _api();
    final info = await _esegui(
      () => api.about.get($fields: 'user(emailAddress)'),
      'lettura account',
    );
    return info.user?.emailAddress;
  }

  /// Elenca gli esami presenti su Drive, ordinati per data decrescente.
  Future<List<EsameRemoto>> listEsami() async {
    final api = await _api();
    final idData = await _idSottocartella(api, Costanti.sottocartellaData);

    final esami = <EsameRemoto>[];
    String? pagina;
    do {
      final risposta = await _esegui(
        () => api.files.list(
          q: "'$idData' in parents and trashed = false",
          $fields: 'nextPageToken, files(id, name, modifiedTime)',
          pageToken: pagina,
        ),
        'elenco esami',
      );
      for (final file in risposta.files ?? const <drive.File>[]) {
        final nome = file.name ?? '';
        if (!_nomeFileJsonRegex.hasMatch(nome)) continue;
        esami.add(
          EsameRemoto(
            dataIso: nome.substring(0, nome.length - '.json'.length),
            jsonFileId: file.id!,
            modificatoIl: file.modifiedTime,
          ),
        );
      }
      pagina = risposta.nextPageToken;
    } while (pagina != null);

    esami.sort((a, b) => b.dataIso.compareTo(a.dataIso));
    return esami;
  }

  /// Carica il PDF originale in `pdf/` come `YYYY-MM-DD.pdf`.
  /// Ritorna l'ID del file creato (o aggiornato, se già presente).
  Future<String> uploadPdf(Uint8List byte, String dataIso) async {
    final api = await _api();
    final idPdf = await _idSottocartella(api, Costanti.sottocartellaPdf);
    return _caricaFile(
      api: api,
      idCartella: idPdf,
      nomeFile: '$dataIso.pdf',
      byte: byte,
      mimeType: 'application/pdf',
    );
  }

  /// Carica (o sovrascrive) il JSON dell'esame in `data/YYYY-MM-DD.json`.
  /// Ritorna l'ID del file su Drive.
  Future<String> uploadJson(Esame esame) async {
    final api = await _api();
    final idData = await _idSottocartella(api, Costanti.sottocartellaData);
    final byte = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(esame.toJson())),
    );
    return _caricaFile(
      api: api,
      idCartella: idData,
      nomeFile: esame.nomeFileJson,
      byte: byte,
      mimeType: 'application/json',
    );
  }

  /// Scarica e decodifica il JSON di un esame dato il suo file ID.
  Future<Esame> downloadJson(String fileId) async {
    final api = await _api();
    final media = await _esegui(
      () async =>
          await api.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media,
      'download esame',
    );

    final buffer = <int>[];
    await media.stream.forEach(buffer.addAll);
    try {
      final json = jsonDecode(utf8.decode(buffer)) as Map<String, dynamic>;
      return Esame.fromJson(json).copyWith(jsonDriveId: fileId);
    } catch (e) {
      throw DriveRepositoryException(
        'JSON dell\'esame non valido (file $fileId)',
        e,
      );
    }
  }

  // ---- Helper privati -----------------------------------------------------

  Future<String> _caricaFile({
    required drive.DriveApi api,
    required String idCartella,
    required String nomeFile,
    required Uint8List byte,
    required String mimeType,
  }) async {
    final media = drive.Media(
      Stream.value(byte),
      byte.length,
      contentType: mimeType,
    );
    final esistente = await _cercaFile(api, nomeFile, idCartella);

    if (esistente != null) {
      final aggiornato = await _esegui(
        () => api.files.update(drive.File(), esistente, uploadMedia: media),
        'aggiornamento $nomeFile',
      );
      return aggiornato.id!;
    }
    final creato = await _esegui(
      () => api.files.create(
        drive.File()
          ..name = nomeFile
          ..parents = [idCartella],
        uploadMedia: media,
      ),
      'caricamento $nomeFile',
    );
    return creato.id!;
  }

  Future<String?> _cercaFile(
    drive.DriveApi api,
    String nome,
    String idCartella,
  ) async {
    final risposta = await _esegui(
      () => api.files.list(
        q:
            "name = '${_sanifica(nome)}' and '$idCartella' in parents "
            'and trashed = false',
        $fields: 'files(id)',
        pageSize: 1,
      ),
      'ricerca $nome',
    );
    final files = risposta.files;
    return (files == null || files.isEmpty) ? null : files.first.id;
  }

  Future<String> _idSottocartella(drive.DriveApi api, String nome) async {
    if (nome == Costanti.sottocartellaPdf && _idCartellaPdf != null) {
      return _idCartellaPdf!;
    }
    if (nome == Costanti.sottocartellaData && _idCartellaData != null) {
      return _idCartellaData!;
    }

    _idCartellaRadice ??= await _idCartella(
      api,
      Costanti.cartellaDrive,
      parent: 'root',
    );
    final id = await _idCartella(api, nome, parent: _idCartellaRadice!);

    if (nome == Costanti.sottocartellaPdf) _idCartellaPdf = id;
    if (nome == Costanti.sottocartellaData) _idCartellaData = id;
    return id;
  }

  /// Trova una cartella per nome dentro [parent], creandola se non esiste.
  Future<String> _idCartella(
    drive.DriveApi api,
    String nome, {
    required String parent,
  }) async {
    final risposta = await _esegui(
      () => api.files.list(
        q:
            "name = '${_sanifica(nome)}' "
            "and mimeType = 'application/vnd.google-apps.folder' "
            "and '$parent' in parents and trashed = false",
        $fields: 'files(id)',
        pageSize: 1,
      ),
      'ricerca cartella $nome',
    );
    final esistenti = risposta.files;
    if (esistenti != null && esistenti.isNotEmpty) return esistenti.first.id!;

    final creata = await _esegui(
      () => api.files.create(
        drive.File()
          ..name = nome
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = [parent],
      ),
      'creazione cartella $nome',
    );
    return creata.id!;
  }

  /// Escape degli apici singoli nelle query Drive.
  static String _sanifica(String valore) => valore.replaceAll("'", r"\'");

  Future<T> _esegui<T>(Future<T> Function() azione, String operazione) async {
    try {
      return await azione();
    } on DriveAuthException {
      rethrow;
    } on drive.DetailedApiRequestError catch (e) {
      throw DriveRepositoryException(
        'Errore Drive durante $operazione (HTTP ${e.status})',
        e,
      );
    } catch (e) {
      throw DriveRepositoryException('Errore durante $operazione', e);
    }
  }
}
