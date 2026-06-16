import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/costanti.dart';
import '../../models/valore_esame.dart';
import '../../providers/providers.dart';
import '../../repositories/vision_repository.dart';
import '../../services/android/android_import_service.dart';
import '../../services/pdf/ocr_parser.dart';
import '../../services/pdf/pdf_testo_estrattore.dart';
import '../../ui/platform/adaptive_button.dart';
import '../../ui/platform/adaptive_platform.dart';
import '../../ui/platform/adaptive_scaffold.dart';
import 'import_controller.dart';
import 'tabella_valori_editor.dart';

/// Import di un referto: selezione PDF → estrazione col modello locale →
/// anteprima editabile → salvataggio su Drive + cache locale.
///
/// Su Android: ML Kit Document Scanner + OCR on-device (o Gemma 2B se scaricato).
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdaptivePlatform.corrente == PiattaformaApp.android) {
      return const _AndroidImportScreen();
    }

    final stato = ref.watch(importControllerProvider);
    final controller = ref.read(importControllerProvider.notifier);
    final modalita = ref.watch(modalitaDesktopProvider).valueOrNull ?? 'vision';

    return AdaptiveScaffold(
      titolo: 'Import',
      body: _DropPdf(
        abilitato: stato is ImportInattivo || stato is ImportErrore,
        onPdf: controller.importaPdf,
        child: switch (stato) {
          ImportInattivo() => _Inattivo(
            onSeleziona: controller.selezionaEdEstrai,
            usaOcr: modalita == 'ocr',
          ),
          ImportInCorso(:final messaggio) => _InCorso(messaggio: messaggio),
          ImportErrore() => _Errore(stato: stato, controller: controller),
          ImportAnteprima(
            :final valori,
            :final avviso,
            :final dataEsame,
            :final analisi,
            :final analisiInCorso,
          ) =>
            TabellaValoriEditor(
              // Key stabile basata sui valori iniziali: non cambia quando
              // arriva l'analisi in background, evitando la perdita degli
              // edit dell'utente.
              key: ValueKey(
                'anteprima-${valori.length}-${dataEsame?.toIso8601String() ?? ''}',
              ),
              valoriIniziali: valori,
              avviso: avviso,
              dataIniziale: dataEsame,
              analisi: analisi,
              analisiInCorso: analisiInCorso,
              onSalva: controller.salva,
              onAnnulla: controller.nuovoImport,
            ),
          ImportSalvato() => _Salvato(stato: stato, controller: controller),
        },
      ),
    );
  }
}

class _Inattivo extends StatelessWidget {
  final VoidCallback onSeleziona;
  final bool usaOcr;

  const _Inattivo({required this.onSeleziona, this.usaOcr = false});

  @override
  Widget build(BuildContext context) {
    final descrizione = usaOcr
        ? 'Modalità OCR: estrae il testo dal PDF e lo analizza con il modello testuale'
        : 'Modalità Vision: rasterizza il PDF e lo analizza con il modello vision';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text(
            'Seleziona il PDF di un referto, o trascinalo qui',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            descrizione,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AdaptiveButton(
            etichetta: 'Seleziona PDF',
            icona: Icons.file_open_outlined,
            onPressed: onSeleziona,
          ),
        ],
      ),
    );
  }
}

class _InCorso extends StatelessWidget {
  final String messaggio;

  const _InCorso({required this.messaggio});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(messaggio, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Errore extends StatelessWidget {
  final ImportErrore stato;
  final ImportController controller;

  const _Errore({required this.stato, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(stato.messaggio, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                AdaptiveButton(
                  etichetta: 'Riprova',
                  icona: Icons.refresh,
                  onPressed: controller.riprovaEstrazione,
                ),
                if (stato.puoInserireManualmente)
                  AdaptiveButton(
                    etichetta: 'Inserisci manualmente',
                    icona: Icons.edit_outlined,
                    onPressed: controller.inserisciManualmente,
                  ),
                AdaptiveButton(
                  etichetta: 'Annulla',
                  onPressed: controller.nuovoImport,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Salvato extends StatelessWidget {
  final ImportSalvato stato;
  final ImportController controller;

  const _Salvato({required this.stato, required this.controller});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final data = DateFormat('dd/MM/yyyy').format(DateTime.parse(stato.dataIso));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              stato.erroreBackup != null
                  ? Icons.warning_amber_outlined
                  : Icons.check_circle_outline,
              size: 56,
              color: stato.erroreBackup != null
                  ? tema.colorScheme.error
                  : const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 12),
            Text('Esame del $data salvato', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              stato.backupOk
                  ? 'Salvato in locale e nel backup'
                  : stato.erroreBackup != null
                  ? 'Salvato in locale. Errore backup:\n${stato.erroreBackup}'
                  : 'Salvato in locale',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            AdaptiveButton(
              etichetta: 'Nuovo import',
              icona: Icons.add,
              onPressed: controller.nuovoImport,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Schermata Import per Android ──────────────────────────────────────────

enum _StatoAndroid { inAttesa, scansione, estrazione, anteprima, errore }

class _AndroidImportScreen extends ConsumerStatefulWidget {
  const _AndroidImportScreen();

  @override
  ConsumerState<_AndroidImportScreen> createState() =>
      _AndroidImportScreenState();
}

class _AndroidImportScreenState extends ConsumerState<_AndroidImportScreen> {
  _StatoAndroid _stato = _StatoAndroid.inAttesa;
  String? _errore;
  bool _llmFallback = false;
  List<ValoreEsame> _valoriEstratti = [];
  DateTime? _dataEsame;
  String? _analisi;
  bool _analisiInCorso = false;

  // Gemma download inline
  bool _llmDisponibile = false;
  bool _downloading = false;
  int _downloadPct = 0;
  String _downloadLabel = '';
  StreamSubscription<ProgressoDownload>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _aggiornaLlmDisponibile();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _aggiornaLlmDisponibile() async {
    final ok = await AndroidImportService.isLlmDisponibile();
    if (mounted) setState(() => _llmDisponibile = ok);
  }

  Future<void> _avviaDownloadGemma() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(Costanti.prefHuggingFaceToken) ?? '';
    setState(() {
      _downloading = true;
      _downloadPct = 0;
      _downloadLabel = '';
    });
    _downloadSub = AndroidImportService.progressoDownload.listen(
      (p) {
        if (mounted) {
          setState(() {
            _downloadPct = p.percentuale;
            _downloadLabel = p.etichetta;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _downloading = false);
      },
    );
    try {
      await AndroidImportService.scaricaModello(token: token);
      if (mounted) setState(() { _llmDisponibile = true; _downloading = false; });
    } on AndroidImportException catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download fallito: ${e.messaggio}')),
        );
      }
    } finally {
      await _downloadSub?.cancel();
      _downloadSub = null;
    }
  }

  // ── Flusso fotocamera ───────────────────────────────────────────────────

  Future<void> _avviaFlussoScanner() async {
    setState(() { _stato = _StatoAndroid.scansione; _errore = null; _llmFallback = false; });
    try {
      final images = await AndroidImportService.avviaScanner();
      if (images == null || images.isEmpty) {
        setState(() => _stato = _StatoAndroid.inAttesa);
        return;
      }
      setState(() => _stato = _StatoAndroid.estrazione);
      final modalita = ref.read(modalitaAndroidProvider).valueOrNull ?? 'ocr';
      String jsonRaw;
      if (modalita == 'llm' && _llmDisponibile) {
        jsonRaw = await AndroidImportService.estraiConLlm(images);
      } else {
        if (modalita == 'llm') setState(() => _llmFallback = true);
        jsonRaw = await AndroidImportService.estraiConOcr(images);
      }
      await _analizzaJson(jsonRaw);
    } on AndroidImportException catch (e) {
      setState(() { _errore = e.messaggio; _stato = _StatoAndroid.errore; });
    } catch (e) {
      setState(() { _errore = 'Errore inatteso: $e'; _stato = _StatoAndroid.errore; });
    }
  }

  // ── Flusso PDF ──────────────────────────────────────────────────────────

  Future<void> _avviaFlussoImportPdf() async {
    final esito = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final pdfBytes = esito?.files.singleOrNull?.bytes;
    if (pdfBytes == null) return;

    setState(() { _stato = _StatoAndroid.estrazione; _errore = null; _llmFallback = false; });
    try {
      final modalita = ref.read(modalitaAndroidProvider).valueOrNull ?? 'ocr';
      final testo = await PdfTestoEstrattore().estraiTesto(pdfBytes);

      if (modalita == 'llm' && _llmDisponibile) {
        // Manda il testo estratto direttamente a Gemma 2B
        final jsonRaw = await AndroidImportService.estraiTestoConLlm(testo);
        await _analizzaJson(jsonRaw);
      } else {
        // Pure OCR (o fallback se Gemma non disponibile)
        if (modalita == 'llm') setState(() => _llmFallback = true);
        final risultato = OcrParser.parseTesto(testo);
        await _mostraAnteprima(risultato.valori, risultato.data, analisi: false);
      }
    } on PdfTestoEstrattoreException {
      setState(() {
        _errore = 'Nessun testo trovato nel PDF. '
            'Per referti scansionati usa la fotocamera.';
        _stato = _StatoAndroid.errore;
      });
    } on AndroidImportException catch (e) {
      setState(() { _errore = e.messaggio; _stato = _StatoAndroid.errore; });
    } catch (e) {
      setState(() { _errore = 'Errore inatteso: $e'; _stato = _StatoAndroid.errore; });
    }
  }

  // ── Parsing e anteprima ─────────────────────────────────────────────────

  Future<void> _analizzaJson(String jsonRaw) async {
    List<ValoreEsame> valori = [];
    DateTime? data;
    try {
      final r = VisionRepository.parseRisposta(jsonRaw);
      valori = r.valori;
      data = r.data;
    } catch (_) {}
    final modalita = ref.read(modalitaAndroidProvider).valueOrNull;
    await _mostraAnteprima(
      valori,
      data,
      analisi: modalita == 'llm' && valori.isNotEmpty,
    );
  }

  Future<void> _mostraAnteprima(
    List<ValoreEsame> valori,
    DateTime? data, {
    required bool analisi,
  }) async {
    setState(() {
      _valoriEstratti = valori;
      _dataEsame = data;
      _analisi = null;
      _analisiInCorso = analisi;
      _stato = _StatoAndroid.anteprima;
    });
    if (analisi) _avviaAnalisiAndroid(valori);
  }

  void _avviaAnalisiAndroid(List<ValoreEsame> valori) async {
    try {
      final vision = await ref.read(visionRepositoryProvider.future);
      final a = await vision.analisiValori(valori);
      if (mounted) setState(() { _analisi = a; _analisiInCorso = false; });
    } catch (_) {
      if (mounted) setState(() => _analisiInCorso = false);
    }
  }

  void _reset() {
    setState(() {
      _stato = _StatoAndroid.inAttesa;
      _errore = null;
      _llmFallback = false;
      _valoriEstratti = [];
      _dataEsame = null;
      _analisi = null;
      _analisiInCorso = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final modalita = ref.watch(modalitaAndroidProvider).valueOrNull ?? 'ocr';

    return AdaptiveScaffold(
      titolo: 'Import',
      body: Column(
        children: [
          if (_llmFallback)
            _BannerLlmFallback(
              onVaiImpostazioni: () {},
            ),
          Expanded(
            child: switch (_stato) {
              _StatoAndroid.inAttesa => _InAttivaAndroid(
                onAvviaScanner: _avviaFlussoScanner,
                onImportaPdf: _avviaFlussoImportPdf,
                usaLlm: modalita == 'llm',
                llmDisponibile: _llmDisponibile,
                downloading: _downloading,
                downloadPct: _downloadPct,
                downloadLabel: _downloadLabel,
                onScaricaLlm: _avviaDownloadGemma,
              ),
              _StatoAndroid.scansione => const _InCorso(messaggio: 'Avvio scanner…'),
              _StatoAndroid.estrazione => const _InCorso(messaggio: 'Estrazione valori…'),
              _StatoAndroid.errore => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errore ?? 'Errore sconosciuto',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          AdaptiveButton(
                            etichetta: 'Scansiona',
                            icona: Icons.camera_alt_outlined,
                            onPressed: _avviaFlussoScanner,
                          ),
                          AdaptiveButton(
                            etichetta: 'Importa PDF',
                            icona: Icons.file_open_outlined,
                            onPressed: _avviaFlussoImportPdf,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _StatoAndroid.anteprima => TabellaValoriEditor(
                key: ValueKey(
                  'android-${_valoriEstratti.length}-${_dataEsame?.toIso8601String() ?? ''}',
                ),
                valoriIniziali: _valoriEstratti,
                avviso: _valoriEstratti.isEmpty
                    ? 'Nessun valore trovato — inseriscili manualmente'
                    : 'Verifica i valori estratti prima di salvare',
                dataIniziale: _dataEsame,
                analisi: _analisi,
                analisiInCorso: _analisiInCorso,
                onSalva: (valori, data) async {
                  final controller = ref.read(importControllerProvider.notifier);
                  await controller.salva(valori, data);
                  if (mounted) _reset();
                },
                onAnnulla: _reset,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _BannerLlmFallback extends StatelessWidget {
  final VoidCallback onVaiImpostazioni;

  const _BannerLlmFallback({required this.onVaiImpostazioni});

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: schema.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: schema.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gemma 2B non scaricato — usato OCR come fallback.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: schema.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InAttivaAndroid extends StatelessWidget {
  final VoidCallback onAvviaScanner;
  final VoidCallback onImportaPdf;
  final bool usaLlm;
  final bool llmDisponibile;
  final bool downloading;
  final int downloadPct;
  final String downloadLabel;
  final VoidCallback onScaricaLlm;

  const _InAttivaAndroid({
    required this.onAvviaScanner,
    required this.onImportaPdf,
    required this.usaLlm,
    required this.llmDisponibile,
    required this.downloading,
    required this.downloadPct,
    required this.downloadLabel,
    required this.onScaricaLlm,
  });

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final String descrizione;
    if (usaLlm && llmDisponibile) {
      descrizione = 'Modalità LLM: Gemma 2B on-device analizza il referto';
    } else {
      descrizione = 'Modalità OCR: analisi testuale on-device senza LLM';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.document_scanner_outlined, size: 72, color: schema.primary),
          const SizedBox(height: 20),
          Text(
            'Importa un referto',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            descrizione,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              AdaptiveButton(
                etichetta: 'Scansiona referto',
                icona: Icons.camera_alt_outlined,
                onPressed: onAvviaScanner,
              ),
              AdaptiveButton(
                etichetta: 'Importa PDF',
                icona: Icons.file_open_outlined,
                onPressed: onImportaPdf,
              ),
            ],
          ),

          // Card download Gemma inline (solo se LLM mode ma modello mancante)
          if (usaLlm && !llmDisponibile) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: schema.outline.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(12),
                color: schema.surfaceContainerLow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology_outlined, color: schema.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Gemma 2B non scaricato',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scarica il modello (~1.5 GB) per usare LLM on-device. '
                    'Puoi anche usare OCR senza scaricarlo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (downloading) ...[
                    LinearProgressIndicator(value: downloadPct / 100),
                    const SizedBox(height: 6),
                    Text(
                      '$downloadPct%  $downloadLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: onScaricaLlm,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Scarica Gemma 2B (~1.5 GB)'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Zona di drop per i PDF: accetta il trascinamento da Finder/Esplora
/// risorse ed evidenzia l'area mentre il file è sopra.
class _DropPdf extends StatefulWidget {
  final bool abilitato;
  final Future<void> Function(Uint8List pdf) onPdf;
  final Widget child;

  const _DropPdf({
    required this.abilitato,
    required this.onPdf,
    required this.child,
  });

  @override
  State<_DropPdf> createState() => _DropPdfState();
}

class _DropPdfState extends State<_DropPdf> {
  bool _inTrascinamento = false;

  Future<void> _onDrop(DropDoneDetails dettagli) async {
    setState(() => _inTrascinamento = false);
    if (!widget.abilitato) return;

    final pdf = dettagli.files
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .firstOrNull;
    if (pdf == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trascina un file PDF')));
      return;
    }
    await widget.onPdf(await pdf.readAsBytes());
  }

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) {
        if (widget.abilitato) setState(() => _inTrascinamento = true);
      },
      onDragExited: (_) => setState(() => _inTrascinamento = false),
      onDragDone: _onDrop,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: _inTrascinamento ? schema.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _inTrascinamento
              ? schema.primary.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Firma del salvataggio esposta a [TabellaValoriEditor].
typedef SalvaEsame =
    Future<void> Function(List<ValoreEsame> valori, DateTime dataEsame);
