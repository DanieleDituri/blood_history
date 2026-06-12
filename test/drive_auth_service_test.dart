import 'dart:convert';

import 'package:esami_tracker/core/costanti.dart';
import 'package:esami_tracker/services/auth/archivio_credenziali.dart';
import 'package:esami_tracker/services/auth/drive_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Client finto: basta che esponga le credenziali, le richieste HTTP non
/// vengono mai eseguite in questi test.
class _FakeAuthClient extends http.BaseClient
    implements AutoRefreshingAuthClient {
  @override
  final AccessCredentials credentials;

  bool chiuso = false;

  _FakeAuthClient(this.credentials);

  @override
  Stream<AccessCredentials> get credentialUpdates => const Stream.empty();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError('Nessuna chiamata HTTP nei test');

  @override
  void close() => chiuso = true;
}

/// Archivio in memoria al posto del keystore di piattaforma.
class _ArchivioInMemoria implements ArchivioCredenziali {
  final Map<String, String> dati = {};

  @override
  Future<String?> leggi(String chiave) async => dati[chiave];

  @override
  Future<void> scrivi(String chiave, String valore) async =>
      dati[chiave] = valore;

  @override
  Future<void> rimuovi(String chiave) async => dati.remove(chiave);
}

AccessCredentials _credenziali({String? refreshToken = 'refresh-1'}) =>
    AccessCredentials(
      AccessToken('Bearer', 'token-1', DateTime.utc(2026, 6, 12, 10)),
      refreshToken,
      const ['https://www.googleapis.com/auth/drive.file'],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DriveAuthService servizio;
  late _ArchivioInMemoria archivio;
  late int chiamateConsenso;
  AccessCredentials? credenzialiConsenso;
  Object? erroreConsenso;

  DriveAuthService creaServizio() => DriveAuthService(
    prefs: SharedPreferences.getInstance(),
    archivio: archivio,
    flussoConsenso: (clientId, scopes) async {
      chiamateConsenso++;
      if (erroreConsenso != null) throw erroreConsenso!;
      return _FakeAuthClient(credenzialiConsenso!);
    },
    clientDaCredenziali: (clientId, credenziali, base) =>
        _FakeAuthClient(credenziali),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      Costanti.prefDriveClientId: 'id-finto.apps.googleusercontent.com',
      Costanti.prefDriveClientSecret: 'secret-finto',
    });
    archivio = _ArchivioInMemoria();
    chiamateConsenso = 0;
    credenzialiConsenso = _credenziali();
    erroreConsenso = null;
    servizio = creaServizio();
  });

  group('collega (autorizzazione una tantum)', () {
    test('esegue il consenso, salva le credenziali e collega', () async {
      await servizio.collega();

      expect(servizio.isCollegato, isTrue);
      expect(chiamateConsenso, 1);

      final salvate =
          jsonDecode(archivio.dati[Costanti.prefCredenzialiDrive]!)
              as Map<String, dynamic>;
      expect(salvate['refresh_token'], 'refresh-1');
      expect(salvate['access_token'], 'token-1');

      // Nel keystore, non in chiaro nelle preferenze.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Costanti.prefCredenzialiDrive), isNull);
    });

    test('senza client id configurato → DriveAuthException', () async {
      SharedPreferences.setMockInitialValues({});
      servizio = creaServizio();

      await expectLater(
        servizio.collega(),
        throwsA(
          isA<DriveAuthException>().having(
            (e) => e.messaggio,
            'messaggio',
            contains('Client ID'),
          ),
        ),
      );
      expect(chiamateConsenso, 0);
    });

    test('errore nel flusso di consenso → DriveAuthException', () async {
      erroreConsenso = Exception('utente ha chiuso il browser');

      await expectLater(servizio.collega(), throwsA(isA<DriveAuthException>()));
      expect(servizio.isCollegato, isFalse);
    });

    test('senza refresh token rifiuta il collegamento', () async {
      // Senza refresh token l'accesso morirebbe alla scadenza del token:
      // meglio fallire subito con istruzioni per ripetere il consenso.
      credenzialiConsenso = _credenziali(refreshToken: null);

      await expectLater(
        servizio.collega(),
        throwsA(
          isA<DriveAuthException>().having(
            (e) => e.messaggio,
            'messaggio',
            contains('refresh token'),
          ),
        ),
      );
      expect(servizio.isCollegato, isFalse);
      expect(archivio.dati, isEmpty);
    });
  });

  group('ripristinaSessione (silenzioso, nessuna interazione)', () {
    test(
      'ripristina dalle credenziali salvate senza aprire il browser',
      () async {
        // Prima esecuzione: consenso. Poi simuliamo un riavvio dell'app.
        await servizio.collega();
        final dopoRiavvio = creaServizio();

        expect(await dopoRiavvio.ripristinaSessione(), isTrue);
        expect(dopoRiavvio.isCollegato, isTrue);
        expect(chiamateConsenso, 1); // solo quella iniziale
      },
    );

    test('false al primo avvio (nessuna credenziale)', () async {
      expect(await servizio.ripristinaSessione(), isFalse);
      expect(servizio.isCollegato, isFalse);
    });

    test('credenziali corrotte → false e pulizia', () async {
      archivio.dati[Costanti.prefCredenzialiDrive] = '{json non valido';

      expect(await servizio.ripristinaSessione(), isFalse);
      expect(archivio.dati, isEmpty);
    });

    test('credenziali salvate senza refresh token → false e pulizia', () async {
      archivio.dati[Costanti.prefCredenzialiDrive] = jsonEncode({
        'token_type': 'Bearer',
        'access_token': 'token-1',
        'expiry': DateTime.utc(2026, 6, 12).toIso8601String(),
        'refresh_token': null,
        'scopes': const ['https://www.googleapis.com/auth/drive.file'],
        'id_token': null,
      });

      expect(await servizio.ripristinaSessione(), isFalse);
      expect(archivio.dati, isEmpty);
    });

    test(
      'migra le credenziali dalle vecchie shared_preferences in chiaro',
      () async {
        // Le prime build salvavano il JSON in shared_preferences: al primo
        // ripristino va spostato nel keystore e tolto dalle preferenze.
        final vecchie = jsonEncode({
          'token_type': 'Bearer',
          'access_token': 'token-vecchio',
          'expiry': DateTime.utc(2026, 6, 12).toIso8601String(),
          'refresh_token': 'refresh-vecchio',
          'scopes': const ['https://www.googleapis.com/auth/drive.file'],
          'id_token': null,
        });
        SharedPreferences.setMockInitialValues({
          Costanti.prefDriveClientId: 'id-finto',
          Costanti.prefCredenzialiDrive: vecchie,
        });
        servizio = creaServizio();

        expect(await servizio.ripristinaSessione(), isTrue);
        expect(archivio.dati[Costanti.prefCredenzialiDrive], vecchie);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(Costanti.prefCredenzialiDrive), isNull);
      },
    );
  });

  group('clientAutenticato', () {
    test('ripristina da solo la sessione se serve', () async {
      await servizio.collega();
      final dopoRiavvio = creaServizio();

      final client = await dopoRiavvio.clientAutenticato();
      expect(client, isA<AutoRefreshingAuthClient>());
      expect(chiamateConsenso, 1); // nessun nuovo consenso
    });

    test('mai autorizzato → DriveAuthException con istruzioni', () async {
      await expectLater(
        servizio.clientAutenticato(),
        throwsA(
          isA<DriveAuthException>().having(
            (e) => e.messaggio,
            'messaggio',
            contains('una volta sola'),
          ),
        ),
      );
    });
  });

  group('scollega', () {
    test('chiude il client e dimentica le credenziali', () async {
      await servizio.collega();
      await servizio.scollega();

      expect(servizio.isCollegato, isFalse);
      expect(archivio.dati, isEmpty);
      expect(await servizio.ripristinaSessione(), isFalse);
    });
  });
}
