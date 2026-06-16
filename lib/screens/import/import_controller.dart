import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/costanti.dart';
import '../../models/esame.dart';
import '../../models/valore_esame.dart';
import '../../providers/providers.dart';
import '../../repositories/vision_repository.dart';
import '../../services/backup/backup_service.dart';
import '../../services/pdf/ocr_parser.dart';
import '../../services/pdf/pdf_rasterizzatore.dart';
import '../../services/pdf/pdf_testo_estrattore.dart';
import '../../services/vision/vision_client.dart';
import '../../ui/platform/adaptive_platform.dart';

/// Stati della schermata Import.
sealed class StatoImport {
  const StatoImport();
}

class ImportInattivo extends StatoImport {
  const ImportInattivo();
}

class ImportInCorso extends StatoImport {
  final String messaggio;
  const ImportInCorso(this.messaggio);
}

class ImportAnteprima extends StatoImport {
  final List<ValoreEsame> valori;
  final String? avviso;
  final DateTime? dataEsame;
  final String? analisi;
  final bool analisiInCorso;

  const ImportAnteprima({
    required this.valori,
    this.avviso,
    this.dataEsame,
    this.analisi,
    this.analisiInCorso = false,
  });
}

class ImportErrore extends StatoImport {
  final String messaggio;
  final bool puoInserireManualmente;
  const ImportErrore(this.messaggio, {this.puoInserireManualmente = false});
}

class ImportSalvato extends StatoImport {
  final String dataIso;
  final bool backupOk;
  final String? erroreBackup;

  const ImportSalvato({
    required this.dataIso,
    this.backupOk = false,
    this.erroreBackup,
  });
}

/// Orchestratore dell'import: selezione PDF → estrazione → anteprima → salvataggio locale.
class ImportController extends StateNotifier<StatoImport> {
  final Ref _ref;
  Uint8List? _pdfCorrente;

  ImportController(this._ref) : super(const ImportInattivo());

  Future<void> selezionaEdEstrai() async {
    final Uint8List? byte;
    try {
      final esito = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      byte = esito?.files.singleOrNull?.bytes;
    } catch (e) {
      state = ImportErrore('Impossibile aprire il selettore file: $e');
      return;
    }
    if (byte == null) return;
    await importaPdf(byte);
  }

  Future<void> importaPdf(Uint8List pdf) async {
    _pdfCorrente = pdf;
    await _estrai(pdf);
  }

  Future<void> _estrai(Uint8List pdf) async {
    state = const ImportInCorso('Lettura del PDF…');
    try {
      String modalita = 'vision';
      if (AdaptivePlatform.corrente != PiattaformaApp.android) {
        final prefs = await SharedPreferences.getInstance();
        modalita = prefs.getString(Costanti.prefModalitaDesktop) ?? 'vision';
      }

      RisultatoEstrazione risultato;
      VisionRepository? vision;

      if (modalita == 'ocr') {
        state = const ImportInCorso('Estrazione testo dal PDF…');
        final estrattore = _ref.read(pdfTestoEstrattoreProvider);
        final testo = await estrattore.estraiTesto(pdf);
        state = const ImportInCorso('Analisi struttura del referto…');
        risultato = OcrParser.parseTesto(testo);
      } else {
        final v = await _ref.read(visionRepositoryProvider.future);
        vision = v;
        final rasterizzatore = _ref.read(pdfRasterizzatoreProvider);
        final pagine = await rasterizzatore.renderizzaPagine(
          pdf,
          onProgresso: (pagina, totale) =>
              state = ImportInCorso('Preparazione pagina $pagina di $totale…'),
        );
        risultato = await v.estraiValori(
          pagine,
          onProgresso: (pagina, totale) => state = ImportInCorso(
            totale == 1
                ? 'Analisi del referto…'
                : 'Analizzando pagina $pagina di $totale…',
          ),
        );
      }

      final avviaAnalisi = vision != null && risultato.valori.isNotEmpty;

      state = ImportAnteprima(
        valori: risultato.valori,
        dataEsame: risultato.data,
        analisiInCorso: avviaAnalisi,
        avviso: risultato.valori.isEmpty
            ? (modalita == 'ocr'
                ? 'Nessun valore trovato nel testo: il PDF potrebbe essere una scansione — prova la modalità Vision'
                : 'Il modello non ha trovato valori: aggiungili manualmente')
            : 'Controlla i valori estratti prima di salvare',
      );

      if (avviaAnalisi) {
        _avviaAnalisiBackground(vision, risultato.valori);
      }
    } on PdfTestoEstrattoreException catch (e) {
      state = ImportErrore(e.messaggio, puoInserireManualmente: true);
    } on PdfRasterException catch (e) {
      state = ImportErrore(e.messaggio);
    } on VisionClientException catch (e) {
      state = ImportErrore(e.messaggio, puoInserireManualmente: true);
    } on EstrazioneNonValidaException {
      state = const ImportErrore(
        'Il modello non ha restituito JSON valido nemmeno al secondo '
        'tentativo: puoi inserire i valori manualmente',
        puoInserireManualmente: true,
      );
    } catch (e) {
      state = ImportErrore(
        'Errore inatteso durante l\'estrazione: $e',
        puoInserireManualmente: true,
      );
    }
  }

  void _avviaAnalisiBackground(
    VisionRepository vision,
    List<ValoreEsame> valori,
  ) async {
    String? analisi;
    try {
      analisi = await vision.analisiValori(valori);
    } catch (_) {
      // L'analisi è opzionale — fallisce silenziosamente.
    }
    if (state is ImportAnteprima) {
      final s = state as ImportAnteprima;
      state = ImportAnteprima(
        valori: s.valori,
        dataEsame: s.dataEsame,
        avviso: s.avviso,
        analisi: analisi,
        analisiInCorso: false,
      );
    }
  }

  Future<void> riprovaEstrazione() async {
    final pdf = _pdfCorrente;
    if (pdf == null) return selezionaEdEstrai();
    await _estrai(pdf);
  }

  void inserisciManualmente() {
    state = const ImportAnteprima(
      valori: [],
      avviso: 'Inserimento manuale: aggiungi i parametri del referto',
    );
  }

  /// Salva l'esame in locale e, se c'è una cartella backup configurata,
  /// esporta automaticamente il JSON.
  Future<void> salva(List<ValoreEsame> valori, DateTime dataEsame) async {
    state = const ImportInCorso('Salvataggio…');

    final esame = Esame(data: dataEsame, valori: valori);
    final repo = _ref.read(esameRepositoryProvider);
    await repo.salvaEsame(esame);
    _ref.invalidate(snapshotProvider);

    // Salva sempre il PDF nella cache interna dell'app (se disponibile).
    final pdf = _pdfCorrente;
    if (pdf != null) {
      await BackupService.salvaPdfInterno(esame.dataIso, pdf);
    }

    // Backup automatico nella cartella utente (non bloccante).
    try {
      final cartella = await BackupService.cartellaBackup();
      if (cartella != null) {
        await BackupService.esportaEsame(esame, pdf: pdf);
        state = ImportSalvato(dataIso: esame.dataIso, backupOk: true);
      } else {
        state = ImportSalvato(dataIso: esame.dataIso);
      }
    } catch (e) {
      state = ImportSalvato(dataIso: esame.dataIso, erroreBackup: '$e');
    }
  }

  void nuovoImport() {
    _pdfCorrente = null;
    state = const ImportInattivo();
  }
}

final importControllerProvider =
    StateNotifierProvider<ImportController, StatoImport>(ImportController.new);
