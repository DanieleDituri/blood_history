import 'package:flutter/services.dart';

import '../../core/costanti.dart';

/// Progresso del download del modello LLM.
class ProgressoDownload {
  final int percentuale; // 0-100
  final int scaricato;   // byte scaricati finora
  final int totale;      // byte totali (-1 se sconosciuto)

  const ProgressoDownload({
    required this.percentuale,
    required this.scaricato,
    required this.totale,
  });

  bool get completato => percentuale >= 100;

  String get etichetta {
    final mb = scaricato / (1024 * 1024);
    if (totale <= 0) return '${mb.toStringAsFixed(0)} MB';
    final totMb = totale / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} / ${totMb.toStringAsFixed(0)} MB';
  }
}

/// Bridge Flutter → Kotlin per le funzionalità Android-native:
/// ML Kit Document Scanner, OCR on-device, MediaPipe LLM (Gemma 2B).
class AndroidImportService {
  AndroidImportService._();

  static const _canaleImport = MethodChannel(
    'com.danieledituri.esami_tracker/android_import',
  );
  static const _canaleDownload = EventChannel(
    'com.danieledituri.esami_tracker/download_modello',
  );

  // ---- LLM: disponibilità / download / cancellazione -------------------------

  /// True se il modello Gemma 2B è già scaricato e pronto all'uso.
  static Future<bool> isLlmDisponibile() async {
    try {
      return await _canaleImport.invokeMethod<bool>('isLlmDisponibile') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Avvia il download del modello Gemma 2B da HuggingFace.
  ///
  /// [token] è il token HuggingFace (necessario per i modelli Gemma con
  /// licenza accettata su hf.co). Può essere vuoto per modelli pubblici.
  /// Ritorna `true` al completamento; lancia eccezione in caso di errore.
  static Future<bool> scaricaModello({String token = ''}) async {
    try {
      final ok = await _canaleImport.invokeMethod<bool>('scaricaModello', {
        'url': Costanti.llmUrlHuggingFace,
        'token': token,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      throw AndroidImportException(
        'Download fallito: ${e.message ?? e.code}',
        e,
      );
    }
  }

  /// Stream con il progresso del download (emette [ProgressoDownload]).
  /// Inizia a emettere solo quando il download è attivo.
  static Stream<ProgressoDownload> get progressoDownload =>
      _canaleDownload.receiveBroadcastStream().map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return ProgressoDownload(
          percentuale: (map['percentuale'] as num).toInt(),
          scaricato: (map['scaricato'] as num).toInt(),
          totale: (map['totale'] as num).toInt(),
        );
      });

  /// Elimina il modello dal dispositivo (libera ~1.5 GB).
  static Future<void> cancellaModello() async {
    try {
      await _canaleImport.invokeMethod<void>('cancellaModello');
    } on PlatformException catch (e) {
      throw AndroidImportException(
        'Cancellazione fallita: ${e.message ?? e.code}',
        e,
      );
    }
  }

  // ---- Scanner + estrazione --------------------------------------------------

  /// Avvia il ML Kit Document Scanner (fotocamera + galleria).
  /// Ritorna la lista di immagini Base64, null se annullato.
  static Future<List<String>?> avviaScanner() async {
    try {
      final result =
          await _canaleImport.invokeMethod<List<dynamic>>('avviaScanner');
      return result?.cast<String>();
    } on PlatformException catch (e) {
      throw AndroidImportException(
        'Errore scanner: ${e.message ?? e.code}',
        e,
      );
    }
  }

  /// Estrae valori via OCR + regex (funziona su tutti i dispositivi).
  static Future<String> estraiConOcr(List<String> base64Images) async {
    try {
      final json = await _canaleImport.invokeMethod<String>('estraiConOcr', {
        'immagini': base64Images,
      });
      return json ?? '{"valori":[]}';
    } on PlatformException catch (e) {
      throw AndroidImportException(
        'Errore OCR: ${e.message ?? e.code}',
        e,
      );
    }
  }

  /// Manda il testo estratto da un PDF a Gemma 2B senza OCR (per PDF con layer testuale).
  static Future<String> estraiTestoConLlm(String testo) async {
    try {
      final json = await _canaleImport.invokeMethod<String>('estraiTestoConLlm', {
        'testo': testo,
      });
      return json ?? '{"valori":[]}';
    } on PlatformException catch (e) {
      throw AndroidImportException('Errore LLM: ${e.message ?? e.code}', e);
    }
  }

  /// Estrae valori via OCR + Gemma 2B on-device (richiede modello scaricato).
  static Future<String> estraiConLlm(List<String> base64Images) async {
    try {
      final json = await _canaleImport.invokeMethod<String>('estraiConLlm', {
        'immagini': base64Images,
      });
      return json ?? '{"valori":[]}';
    } on PlatformException catch (e) {
      throw AndroidImportException(
        'Errore LLM: ${e.message ?? e.code}',
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
