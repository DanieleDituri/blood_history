import 'dart:convert';
import 'dart:io';

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

/// Gestisce il backup/ripristino degli esami su una cartella locale scelta
/// dall'utente. I file sono salvati come JSON in `<cartella>/esami/YYYY-MM-DD.json`.
class BackupService {
  /// Apre il dialog di selezione cartella e salva il percorso scelto.
  /// Ritorna il percorso selezionato, o null se l'utente annulla.
  static Future<String?> scegliCartella() async {
    final percorso = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Scegli la cartella di backup',
    );
    if (percorso == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Costanti.prefCartellaBackup, percorso);
    return percorso;
  }

  /// Ritorna la cartella di backup salvata, o null se non è stata scelta.
  static Future<String?> cartellaBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Costanti.prefCartellaBackup);
  }

  /// Esporta un singolo esame nella cartella di backup.
  static Future<void> esportaEsame(Esame esame) async {
    final cartella = await cartellaBackup();
    if (cartella == null) throw const BackupException('Nessuna cartella di backup configurata');
    final dir = Directory(p.join(cartella, 'esami'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${esame.dataIso}.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(esame.toJson()),
    );
  }

  /// Esporta tutti gli esami nella cartella di backup.
  static Future<int> esportaTutti(List<Esame> esami) async {
    var count = 0;
    for (final esame in esami) {
      await esportaEsame(esame);
      count++;
    }
    return count;
  }

  /// Importa tutti i JSON dalla cartella di backup.
  /// Ritorna la lista degli esami importati.
  static Future<List<Esame>> importaDaCartella() async {
    final cartella = await cartellaBackup();
    if (cartella == null) throw const BackupException('Nessuna cartella di backup configurata');
    final dir = Directory(p.join(cartella, 'esami'));
    if (!await dir.exists()) return [];

    final esami = <Esame>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final json = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
          esami.add(Esame.fromJson(json));
        } catch (_) {
          // Salta i file non validi
        }
      }
    }
    esami.sort((a, b) => b.data.compareTo(a.data));
    return esami;
  }

  /// Elimina il file di backup di un esame.
  static Future<void> eliminaBackup(String dataIso) async {
    final cartella = await cartellaBackup();
    if (cartella == null) return;
    final file = File(p.join(cartella, 'esami', '$dataIso.json'));
    if (await file.exists()) await file.delete();
  }
}
