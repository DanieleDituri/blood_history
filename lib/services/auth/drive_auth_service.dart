import 'dart:convert';

import 'package:googleapis/drive/v3.dart' show DriveApi;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/costanti.dart';
import 'archivio_credenziali.dart';

/// Errore di accesso a Google Drive, con causa leggibile per la UI.
class DriveAuthException implements Exception {
  final String messaggio;
  final Object? causa;

  const DriveAuthException(this.messaggio, [this.causa]);

  @override
  String toString() =>
      'DriveAuthException: $messaggio${causa != null ? ' ($causa)' : ''}';
}

/// Flusso di consenso OAuth, iniettabile nei test (il default usa
/// [clientViaUserConsent] e apre il browser di sistema).
typedef FlussoConsenso =
    Future<AutoRefreshingAuthClient> Function(
      ClientId clientId,
      List<String> scopes,
    );

/// Costruzione del client da credenziali salvate, iniettabile nei test
/// (default: [autoRefreshingClient]).
typedef ClientDaCredenziali =
    AutoRefreshingAuthClient Function(
      ClientId clientId,
      AccessCredentials credenziali,
      http.Client base,
    );

/// Accesso a Google Drive **senza login ricorrente**.
///
/// L'app è personale: non c'è Google Sign-In né account picker. Il flusso è:
///
/// 1. Una sola volta (per dispositivo) si chiama [collega]: si apre il
///    browser sulla pagina di consenso Google, l'utente clicca "Consenti",
///    il codice torna all'app via loopback (`http://localhost`).
/// 2. Le credenziali — refresh token incluso — vengono salvate localmente.
/// 3. Da quel momento [clientAutenticato] ripristina la sessione in
///    silenzio e rinnova da solo il token di accesso quando scade
///    ([AutoRefreshingAuthClient]). Nessuna interazione, mai più.
///
/// Funziona uguale su macOS, Windows e Android (il browser di sistema
/// raggiunge il server di loopback dell'app anche su Android).
///
/// Lo scope è `drive.file`: l'app vede SOLO i file che crea lei stessa,
/// non il resto del Drive.
///
/// Servono un Client ID e secret OAuth di tipo "Desktop" del proprio
/// progetto Google Cloud: o compilati nell'app con
/// `--dart-define=DRIVE_CLIENT_ID=... --dart-define=DRIVE_CLIENT_SECRET=...`
/// o inseriti nelle Impostazioni. Il progetto va messo "In produzione"
/// (non "Testing"), altrimenti Google fa scadere il refresh token dopo
/// 7 giorni.
class DriveAuthService {
  static const _scopes = [DriveApi.driveFileScope];

  /// Default compilati nel binario con --dart-define (vuoti se assenti).
  static const _clientIdDefault = String.fromEnvironment('DRIVE_CLIENT_ID');
  static const _clientSecretDefault = String.fromEnvironment(
    'DRIVE_CLIENT_SECRET',
  );

  /// Prefs: solo configurazione (client id/secret dalle Impostazioni).
  final Future<SharedPreferences> _prefs;

  /// Credenziali OAuth (refresh token incluso): keystore di piattaforma.
  final ArchivioCredenziali _archivio;

  final FlussoConsenso _flussoConsenso;
  final ClientDaCredenziali _clientDaCredenziali;

  AutoRefreshingAuthClient? _client;

  DriveAuthService({
    Future<SharedPreferences>? prefs,
    ArchivioCredenziali? archivio,
    FlussoConsenso? flussoConsenso,
    ClientDaCredenziali? clientDaCredenziali,
  }) : _prefs = prefs ?? SharedPreferences.getInstance(),
       _archivio = archivio ?? const ArchivioCredenzialiSicuro(),
       _flussoConsenso = flussoConsenso ?? _consensoNelBrowser,
       _clientDaCredenziali = clientDaCredenziali ?? autoRefreshingClient;

  /// True se il collegamento a Drive è attivo in questa istanza.
  bool get isCollegato => _client != null;

  /// Autorizzazione una tantum: apre il browser per il consenso e salva
  /// le credenziali. Da chiamare solo se [ripristinaSessione] fallisce
  /// (primo avvio su un dispositivo, o accesso revocato).
  ///
  /// Lancia [DriveAuthException] se il Client ID non è configurato o il
  /// flusso fallisce.
  Future<void> collega() async {
    final clientId = await _clientId();
    try {
      _client = await _flussoConsenso(clientId, _scopes);
    } on DriveAuthException {
      rethrow;
    } catch (e) {
      throw DriveAuthException('Autorizzazione a Drive non riuscita', e);
    }
    if (_client!.credentials.refreshToken == null) {
      // Senza refresh token il "mai più login" non è garantito: meglio
      // fallire subito che scoprirlo alla scadenza del token.
      _client!.close();
      _client = null;
      throw const DriveAuthException(
        'Google non ha restituito un refresh token: revoca l\'accesso '
        'dell\'app su myaccount.google.com/permissions e riprova',
      );
    }
    await _salvaCredenziali(_client!.credentials);
  }

  /// Ripristina il collegamento dalle credenziali salvate, senza alcuna
  /// interazione. Ritorna false se non ci sono credenziali utilizzabili
  /// (in quel caso serve [collega], una volta sola).
  Future<bool> ripristinaSessione() async {
    if (_client != null) return true;
    final salvate =
        await _archivio.leggi(Costanti.prefCredenzialiDrive) ??
        await _migraDaPreferenze();
    if (salvate == null) return false;
    try {
      final credenziali = _credenzialiDaJson(
        jsonDecode(salvate) as Map<String, dynamic>,
      );
      if (credenziali.refreshToken == null) {
        await _archivio.rimuovi(Costanti.prefCredenzialiDrive);
        return false;
      }
      _client = _clientDaCredenziali(
        await _clientId(),
        credenziali,
        http.Client(),
      );
      return true;
    } catch (_) {
      // Credenziali corrotte o client id cambiato: si ripulisce e al
      // prossimo uso servirà una nuova autorizzazione.
      await _archivio.rimuovi(Costanti.prefCredenzialiDrive);
      _client = null;
      return false;
    }
  }

  /// Migrazione una tantum: le prime build salvavano le credenziali in
  /// chiaro in shared_preferences. Se le trova, le sposta nel keystore
  /// e ripulisce. Da rimuovere quando non servirà più.
  Future<String?> _migraDaPreferenze() async {
    final prefs = await _prefs;
    final vecchie = prefs.getString(Costanti.prefCredenzialiDrive);
    if (vecchie == null) return null;
    await _archivio.scrivi(Costanti.prefCredenzialiDrive, vecchie);
    await prefs.remove(Costanti.prefCredenzialiDrive);
    return vecchie;
  }

  /// Scollega Drive e dimentica le credenziali salvate.
  Future<void> scollega() async {
    _client?.close();
    _client = null;
    await _archivio.rimuovi(Costanti.prefCredenzialiDrive);
  }

  /// Client HTTP autenticato, con token rinnovato automaticamente.
  /// Ripristina la sessione da solo se serve; lancia [DriveAuthException]
  /// solo se non è mai stata fatta l'autorizzazione iniziale.
  Future<http.Client> clientAutenticato() async {
    if (_client == null && !await ripristinaSessione()) {
      throw const DriveAuthException(
        'Drive non ancora collegato: autorizza l\'accesso (una volta sola) '
        'dalle Impostazioni',
      );
    }
    // Il refresh può ruotare le credenziali: ripersistiamo le più recenti.
    await _salvaCredenziali(_client!.credentials);
    return _client!;
  }

  // ---- Configurazione client OAuth ----------------------------------------

  Future<ClientId> _clientId() async {
    final prefs = await _prefs;
    final id = prefs.getString(Costanti.prefDriveClientId) ?? _clientIdDefault;
    final secret =
        prefs.getString(Costanti.prefDriveClientSecret) ?? _clientSecretDefault;
    if (id.isEmpty) {
      throw const DriveAuthException(
        'Client ID Google non configurato: compila l\'app con '
        '--dart-define=DRIVE_CLIENT_ID=… o inseriscilo nelle Impostazioni',
      );
    }
    return ClientId(id, secret.isEmpty ? null : secret);
  }

  static Future<AutoRefreshingAuthClient> _consensoNelBrowser(
    ClientId clientId,
    List<String> scopes,
  ) => clientViaUserConsent(clientId, scopes, _apriBrowser);

  static void _apriBrowser(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ---- Persistenza credenziali ---------------------------------------------

  Future<void> _salvaCredenziali(AccessCredentials credenziali) =>
      _archivio.scrivi(
        Costanti.prefCredenzialiDrive,
        jsonEncode(_credenzialiAJson(credenziali)),
      );

  // googleapis_auth non offre (de)serializzazione: la facciamo a mano.
  static Map<String, dynamic> _credenzialiAJson(AccessCredentials c) => {
    'token_type': c.accessToken.type,
    'access_token': c.accessToken.data,
    'expiry': c.accessToken.expiry.toIso8601String(),
    'refresh_token': c.refreshToken,
    'scopes': c.scopes,
    'id_token': c.idToken,
  };

  static AccessCredentials _credenzialiDaJson(Map<String, dynamic> json) =>
      AccessCredentials(
        AccessToken(
          json['token_type'] as String,
          json['access_token'] as String,
          DateTime.parse(json['expiry'] as String).toUtc(),
        ),
        json['refresh_token'] as String?,
        (json['scopes'] as List<dynamic>).cast<String>(),
        idToken: json['id_token'] as String?,
      );
}
