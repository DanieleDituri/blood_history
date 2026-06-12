import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/esame.dart';
import '../../models/valore_esame.dart';
import '../../providers/providers.dart';
import '../../repositories/vision_repository.dart';
import '../../services/auth/drive_auth_service.dart';
import '../../services/pdf/pdf_rasterizzatore.dart';
import '../../services/vision/vision_client.dart';

/// Stati della schermata Import.
sealed class StatoImport {
  const StatoImport();
}

/// Nessun import in corso: si può selezionare un PDF.
class ImportInattivo extends StatoImport {
  const ImportInattivo();
}

/// Estrazione o salvataggio in corso, con messaggio di progresso
/// (es. "Analizzando pagina 1 di 2…").
class ImportInCorso extends StatoImport {
  final String messaggio;

  const ImportInCorso(this.messaggio);
}

/// Valori estratti (o vuoti, per inserimento manuale): in attesa di
/// correzione/conferma da parte dell'utente.
class ImportAnteprima extends StatoImport {
  final List<ValoreEsame> valori;

  /// Avviso non bloccante da mostrare sopra la tabella.
  final String? avviso;

  const ImportAnteprima({required this.valori, this.avviso});
}

/// Estrazione fallita prima dell'anteprima.
class ImportErrore extends StatoImport {
  final String messaggio;

  /// True se ha senso offrire l'inserimento manuale (abbiamo comunque
  /// il PDF da archiviare).
  final bool puoInserireManualmente;

  const ImportErrore(this.messaggio, {this.puoInserireManualmente = false});
}

/// Esame salvato in cache locale; [driveOk] dice se anche l'upload su
/// Drive è riuscito.
class ImportSalvato extends StatoImport {
  final String dataIso;
  final bool driveOk;
  final String? erroreDrive;

  /// True se l'upload è fallito perché Drive non è ancora autorizzato:
  /// la UI offre "Collega Drive e riprova".
  final bool driveNonCollegato;

  const ImportSalvato({
    required this.dataIso,
    required this.driveOk,
    this.erroreDrive,
    this.driveNonCollegato = false,
  });
}

/// Orchestratore dell'import: selezione PDF → rasterizzazione →
/// estrazione col modello locale → anteprima → salvataggio
/// (sempre in locale, poi su Drive).
class ImportController extends StateNotifier<StatoImport> {
  final Ref _ref;

  /// PDF dell'import corrente: serve per l'upload e per riprovare.
  Uint8List? _pdfCorrente;

  /// Ultimo esame salvato in locale, per riprovare l'upload su Drive.
  Esame? _esameDaCaricare;

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
      // Senza questo catch un errore del picker (es. entitlement mancanti)
      // morirebbe in silenzio e la UI resterebbe immobile.
      state = ImportErrore('Impossibile aprire il selettore file: $e');
      return;
    }
    if (byte == null) return; // selezione annullata

    await importaPdf(byte);
  }

  /// Avvia l'import dai byte di un PDF (dal picker o dal drag&drop).
  Future<void> importaPdf(Uint8List pdf) async {
    _pdfCorrente = pdf;
    await _estrai(pdf);
  }

  Future<void> _estrai(Uint8List pdf) async {
    state = const ImportInCorso('Lettura del PDF…');
    try {
      final rasterizzatore = _ref.read(pdfRasterizzatoreProvider);
      final pagine = await rasterizzatore.renderizzaPagine(
        pdf,
        onProgresso: (pagina, totale) =>
            state = ImportInCorso('Preparazione pagina $pagina di $totale…'),
      );

      final vision = await _ref.read(visionRepositoryProvider.future);
      final valori = await vision.estraiValori(
        pagine,
        onProgresso: (pagina, totale) => state = ImportInCorso(
          totale == 1
              ? 'Analisi del referto…'
              : 'Analizzando pagina $pagina di $totale…',
        ),
      );

      state = ImportAnteprima(
        valori: valori,
        avviso: valori.isEmpty
            ? 'Il modello non ha trovato valori: aggiungili manualmente'
            : 'Controlla i valori estratti prima di salvare',
      );
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

  /// Riprova l'estrazione sull'ultimo PDF selezionato.
  Future<void> riprovaEstrazione() async {
    final pdf = _pdfCorrente;
    if (pdf == null) return selezionaEdEstrai();
    await _estrai(pdf);
  }

  /// Salta l'estrazione: anteprima vuota da compilare a mano (il PDF,
  /// se presente, viene comunque archiviato al salvataggio).
  void inserisciManualmente() {
    state = const ImportAnteprima(
      valori: [],
      avviso: 'Inserimento manuale: aggiungi i parametri del referto',
    );
  }

  /// Salva l'esame: prima in cache locale (mai perdere dati), poi su
  /// Drive (PDF + JSON). Il fallimento Drive non è bloccante.
  Future<void> salva(List<ValoreEsame> valori, DateTime dataEsame) async {
    state = const ImportInCorso('Salvataggio…');

    var esame = Esame(data: dataEsame, valori: valori);
    final repo = _ref.read(esameRepositoryProvider);
    await repo.salvaEsame(esame);
    _ref.invalidate(snapshotProvider);

    _esameDaCaricare = esame;
    await _caricaSuDrive(esame);
  }

  Future<void> _caricaSuDrive(Esame esame) async {
    final drive = _ref.read(driveRepositoryProvider);
    final repo = _ref.read(esameRepositoryProvider);
    try {
      final pdf = _pdfCorrente;
      String? pdfId;
      if (pdf != null) {
        state = const ImportInCorso('Caricamento PDF su Drive…');
        pdfId = await drive.uploadPdf(pdf, esame.dataIso);
      }
      state = const ImportInCorso('Caricamento dati su Drive…');
      final conPdf = esame.copyWith(pdfDriveId: pdfId);
      final jsonId = await drive.uploadJson(conPdf);
      await repo.salvaEsame(conPdf.copyWith(jsonDriveId: jsonId));

      _esameDaCaricare = null;
      state = ImportSalvato(dataIso: esame.dataIso, driveOk: true);
    } on DriveAuthException catch (e) {
      state = ImportSalvato(
        dataIso: esame.dataIso,
        driveOk: false,
        erroreDrive: e.messaggio,
        driveNonCollegato: true,
      );
    } catch (e) {
      state = ImportSalvato(
        dataIso: esame.dataIso,
        driveOk: false,
        erroreDrive: '$e',
      );
    }
  }

  /// Autorizza Drive (consenso una tantum) e riprova l'upload
  /// dell'ultimo esame salvato solo in locale.
  Future<void> collegaDriveERiprova() async {
    final esame = _esameDaCaricare;
    if (esame == null) return;
    state = const ImportInCorso('Collegamento a Drive…');
    try {
      await _ref.read(authServiceProvider).collega();
    } on DriveAuthException catch (e) {
      state = ImportSalvato(
        dataIso: esame.dataIso,
        driveOk: false,
        erroreDrive: e.messaggio,
        driveNonCollegato: true,
      );
      return;
    }
    await _caricaSuDrive(esame);
  }

  void nuovoImport() {
    _pdfCorrente = null;
    _esameDaCaricare = null;
    state = const ImportInattivo();
  }
}

final importControllerProvider =
    StateNotifierProvider<ImportController, StatoImport>(ImportController.new);
