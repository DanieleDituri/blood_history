import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
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
///   dati/   ← dati strutturati   YYYY-MM-DD.json  (valori, range, grafici)
/// ```
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

  /// Esporta un esame nella cartella di backup.
  /// Se [pdf] è fornito, salva anche il PDF originale in `pdf/`.
  static Future<void> esportaEsame(Esame esame, {Uint8List? pdf}) async {
    final cartella = await cartellaBackup();
    if (cartella == null) {
      throw const BackupException('Nessuna cartella di backup configurata');
    }

    // Dati strutturati → dati/YYYY-MM-DD.json
    final dirDati = Directory(p.join(cartella, _sottocartellaData));
    await dirDati.create(recursive: true);
    await File(p.join(dirDati.path, '${esame.dataIso}.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(esame.toJson()),
    );

    // PDF originale → pdf/YYYY-MM-DD.pdf (solo se disponibile)
    if (pdf != null) {
      final dirPdf = Directory(p.join(cartella, _sottocartellaPdf));
      await dirPdf.create(recursive: true);
      await File(p.join(dirPdf.path, '${esame.dataIso}.pdf')).writeAsBytes(pdf);
    }
  }

  /// Esporta tutti gli esami (solo JSON, i PDF non sono in memoria).
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
    final cartella = await cartellaBackup();
    if (cartella == null) return;
    for (final sub in [_sottocartellaData, _sottocartellaPdf]) {
      final ext = sub == _sottocartellaPdf ? 'pdf' : 'json';
      final file = File(p.join(cartella, sub, '$dataIso.$ext'));
      if (await file.exists()) await file.delete();
    }
  }
}
