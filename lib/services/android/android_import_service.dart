import 'package:flutter/services.dart';

/// Bridge Flutter → Kotlin per le funzionalità Android-native:
/// ML Kit Document Scanner + Gemini Nano (AICore).
///
/// Ogni metodo è no-op su piattaforme non-Android: il chiamante deve
/// già trovarsi in un branch `if (Platform.isAndroid)` o equivalente.
class AndroidImportService {
  AndroidImportService._();

  static const _canale = MethodChannel(
    'com.danieledituri.esami_tracker/android_import',
  );

  /// Ritorna `true` se AICore/Gemini Nano è disponibile sul dispositivo
  /// (richiede Android 14+ e un Pixel 8/9 series compatibile).
  static Future<bool> isAiCoreSupported() async {
    try {
      return await _canale.invokeMethod<bool>('isAiCoreSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Avvia il ML Kit Document Scanner (fotocamera + galleria).
  ///
  /// Ritorna la lista di immagini scansionate come stringhe Base64, oppure
  /// `null` se l'utente annulla. Lancia un'eccezione in caso di errore.
  static Future<List<String>?> avviaScanner() async {
    try {
      final result = await _canale.invokeMethod<List<dynamic>>('avviaScanner');
      return result?.cast<String>();
    } on PlatformException catch (e) {
      throw AndroidImportException(
        'Errore scanner: ${e.message ?? e.code}',
        e,
      );
    }
  }

  /// Usa ML Kit Text Recognition + Gemini Nano per estrarre i valori
  /// degli esami dalle immagini Base64 fornite.
  ///
  /// Ritorna il JSON grezzo prodotto da Gemini Nano (stringa da parsare).
  /// Lancia [AndroidImportException] in caso di errore AICore.
  static Future<String> estraiTesto(List<String> base64Images) async {
    try {
      final json = await _canale.invokeMethod<String>('estraiTesto', {
        'immagini': base64Images,
      });
      return json ?? '';
    } on PlatformException catch (e) {
      throw AndroidImportException(
        'Errore Gemini Nano: ${e.message ?? e.code}',
        e,
      );
    }
  }
}

class AndroidImportException implements Exception {
  final String messaggio;
  final Object? causa;

  const AndroidImportException(this.messaggio, [this.causa]);

  @override
  String toString() =>
      'AndroidImportException: $messaggio'
      '${causa != null ? ' ($causa)' : ''}';
}
