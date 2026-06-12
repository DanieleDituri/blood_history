import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistenza chiave/valore per le credenziali OAuth.
///
/// Astrazione minima sopra [FlutterSecureStorage]: permette di iniettare
/// un archivio in memoria nei test e, volendo, di cambiare backend.
abstract class ArchivioCredenziali {
  Future<String?> leggi(String chiave);
  Future<void> scrivi(String chiave, String valore);
  Future<void> rimuovi(String chiave);
}

/// Implementazione di default: keystore della piattaforma.
///
/// - macOS → Keychain. Si usa il keychain classico (login) e non il "data
///   protection keychain", che richiederebbe la firma con un certificato
///   Apple Developer: così funziona anche con la firma ad-hoc delle build
///   locali. Per una versione pubblica firmata si può rimettere a true.
/// - Android → Keystore (minSdk 23)
/// - Windows → DPAPI
class ArchivioCredenzialiSicuro implements ArchivioCredenziali {
  final FlutterSecureStorage _storage;

  const ArchivioCredenzialiSicuro([
    this._storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  ]);

  @override
  Future<String?> leggi(String chiave) => _storage.read(key: chiave);

  @override
  Future<void> scrivi(String chiave, String valore) =>
      _storage.write(key: chiave, value: valore);

  @override
  Future<void> rimuovi(String chiave) => _storage.delete(key: chiave);
}
