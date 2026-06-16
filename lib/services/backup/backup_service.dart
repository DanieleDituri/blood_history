import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/costanti.dart';
import '../../models/esame.dart';

class BackupException implements Exception {
  final String messaggio;
  const BackupException(this.messaggio);
  @override
  String toString() => messaggio;
}

/// Struttura cartella di backup:
///
/// ```
/// <cartella scelta>/
///   pdf/    ← referti originali  YYYY-MM-DD.pdf
///   dati/   ← dati strutturati   YYYY-MM-DD.json
/// ```
///
/// I PDF vengono sempre salvati anche nella cartella documenti dell'app
/// (`<appDocDir>/pdf/`) in modo da essere disponibili per l'export anche
/// se la cartella di backup viene scelta dopo l'import.
class BackupService {
  static const _sottocartellaPdf = 'pdf';
  static const _sottocartellaData = 'dati';

  static Future<String?> scegliCartella() async {
    final percorso = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Scegli la cartella di backup',
    );
    if (percorso == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Costanti.prefCartellaBackup, percorso);
    return percorso;
  }

  static Future<String?> cartellaBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Costanti.prefCartellaBackup);
  }

  /// Cartella interna dell'app dove teniamo i PDF originali.
  static Future<Directory> _dirPdfInterna() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'pdf'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Salva il PDF nella cache interna dell'app (sempre, indipendentemente
  /// dalla cartella di backup).
  static Future<void> salvaPdfInterno(String dataIso, Uint8List pdf) async {
    final dir = await _dirPdfInterna();
    await File(p.join(dir.path, '$dataIso.pdf')).writeAsBytes(pdf);
  }

  /// Legge il PDF dalla cache interna, null se non presente.
  static Future<Uint8List?> leggiPdfInterno(String dataIso) async {
    final dir = await _dirPdfInterna();
    final file = File(p.join(dir.path, '$dataIso.pdf'));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Esporta un esame nella cartella di backup scelta dall'utente.
  /// Salva il JSON in `dati/` e, se disponibile nella cache interna, il PDF in `pdf/`.
  static Future<void> esportaEsame(Esame esame, {Uint8List? pdf}) async {
    final cartella = await cartellaBackup();
    if (cartella == null) {
      throw const BackupException('Nessuna cartella di backup configurata');
    }

    // JSON → dati/YYYY-MM-DD.json
    final dirDati = Directory(p.join(cartella, _sottocartellaData));
    await dirDati.create(recursive: true);
    await File(p.join(dirDati.path, '${esame.dataIso}.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(esame.toJson()),
    );

    // PDF → pdf/YYYY-MM-DD.pdf
    // Usa i byte passati direttamente, altrimenti cerca nella cache interna.
    final pdfBytes = pdf ?? await leggiPdfInterno(esame.dataIso);
    if (pdfBytes != null) {
      final dirPdf = Directory(p.join(cartella, _sottocartellaPdf));
      await dirPdf.create(recursive: true);
      await File(p.join(dirPdf.path, '${esame.dataIso}.pdf'))
          .writeAsBytes(pdfBytes);
    }
  }

  /// Esporta tutti gli esami: JSON sempre, PDF quando presenti in cache interna.
  static Future<int> esportaTutti(List<Esame> esami) async {
    var count = 0;
    for (final esame in esami) {
      await esportaEsame(esame);
      count++;
    }
    return count;
  }

  /// Importa tutti i JSON da `dati/`.
  static Future<List<Esame>> importaDaCartella() async {
    final cartella = await cartellaBackup();
    if (cartella == null) {
      throw const BackupException('Nessuna cartella di backup configurata');
    }
    final dir = Directory(p.join(cartella, _sottocartellaData));
    if (!await dir.exists()) return [];

    final esami = <Esame>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final json =
              jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
          esami.add(Esame.fromJson(json));
        } catch (_) {
          // Salta i file non validi
        }
      }
    }
    esami.sort((a, b) => b.data.compareTo(a.data));
    return esami;
  }

  static Future<void> eliminaBackup(String dataIso) async {
    // Rimuove dalla cache interna
    final dirInt = await _dirPdfInterna();
    final pdfInt = File(p.join(dirInt.path, '$dataIso.pdf'));
    if (await pdfInt.exists()) await pdfInt.delete();

    // Rimuove dalla cartella di backup utente
    final cartella = await cartellaBackup();
    if (cartella == null) return;
    for (final entry in {
      _sottocartellaPdf: 'pdf',
      _sottocartellaData: 'json',
    }.entries) {
      final file = File(p.join(cartella, entry.key, '$dataIso.${entry.value}'));
      if (await file.exists()) await file.delete();
    }
  }
}
