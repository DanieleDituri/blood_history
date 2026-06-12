import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/valore_esame.dart';
import '../../repositories/vision_repository.dart';
import '../../services/android/android_import_service.dart';
import '../../ui/platform/adaptive_button.dart';
import '../../ui/platform/adaptive_platform.dart';
import '../../ui/platform/adaptive_scaffold.dart';
import 'import_controller.dart';
import 'tabella_valori_editor.dart';

/// Import di un referto: selezione PDF → estrazione col modello locale →
/// anteprima editabile → salvataggio su Drive + cache locale.
///
/// Su Android: ML Kit Document Scanner + Gemini Nano (AICore).
/// Fallback a inserimento manuale se AICore non è supportato.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdaptivePlatform.corrente == PiattaformaApp.android) {
      return const _AndroidImportScreen();
    }

    final stato = ref.watch(importControllerProvider);
    final controller = ref.read(importControllerProvider.notifier);

    return AdaptiveScaffold(
      titolo: 'Import',
      body: _DropPdf(
        // Il drop ha senso solo quando non c'è già un import in corso.
        abilitato: stato is ImportInattivo || stato is ImportErrore,
        onPdf: controller.importaPdf,
        child: switch (stato) {
          ImportInattivo() => _Inattivo(
            onSeleziona: controller.selezionaEdEstrai,
          ),
          ImportInCorso(:final messaggio) => _InCorso(messaggio: messaggio),
          ImportErrore() => _Errore(stato: stato, controller: controller),
          ImportAnteprima(:final valori, :final avviso, :final dataEsame) =>
            TabellaValoriEditor(
              // Una key nuova per ogni anteprima: i controller di testo
              // ripartono dai valori estratti.
              key: ObjectKey(stato),
              valoriIniziali: valori,
              avviso: avviso,
              dataIniziale: dataEsame,
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

  const _Inattivo({required this.onSeleziona});

  @override
  Widget build(BuildContext context) {
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
            'L\'analisi avviene in locale con il tuo modello vision',
            style: Theme.of(context).textTheme.bodySmall,
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
              stato.driveOk ? Icons.check_circle_outline : Icons.cloud_off,
              size: 56,
              color: stato.driveOk
                  ? const Color(0xFF2E7D32)
                  : tema.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text('Esame del $data salvato', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              stato.driveOk
                  ? 'Archiviato in locale e su Google Drive'
                  : 'Salvato in locale, ma l\'upload su Drive è fallito:\n'
                        '${stato.erroreDrive}',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (stato.driveNonCollegato)
                  AdaptiveButton(
                    etichetta: 'Collega Drive e riprova',
                    icona: Icons.cloud_upload_outlined,
                    onPressed: controller.collegaDriveERiprova,
                  ),
                AdaptiveButton(
                  etichetta: 'Nuovo import',
                  icona: Icons.add,
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

// ─── Schermata Import per Android ──────────────────────────────────────────

/// Stati specifici della schermata Android.
enum _StatoAndroid { inAttesa, scansione, estrazione, anteprima, errore }

class _AndroidImportScreen extends StatefulWidget {
  const _AndroidImportScreen();

  @override
  State<_AndroidImportScreen> createState() => _AndroidImportScreenState();
}

class _AndroidImportScreenState extends State<_AndroidImportScreen> {
  _StatoAndroid _stato = _StatoAndroid.inAttesa;
  bool? _aiCoreDisponibile;
  String? _errore;
  List<String> _base64Images = [];
  List<ValoreEsame> _valoriEstratti = [];
  DateTime? _dataEsame;

  @override
  void initState() {
    super.initState();
    _verificaAiCore();
  }

  Future<void> _verificaAiCore() async {
    final supportato = await AndroidImportService.isAiCoreSupported();
    if (mounted) setState(() => _aiCoreDisponibile = supportato);
  }

  Future<void> _avviaFlusso() async {
    setState(() {
      _stato = _StatoAndroid.scansione;
      _errore = null;
    });

    try {
      final images = await AndroidImportService.avviaScanner();
      if (images == null || images.isEmpty) {
        // Utente ha annullato
        setState(() => _stato = _StatoAndroid.inAttesa);
        return;
      }
      _base64Images = images;

      if (_aiCoreDisponibile == true) {
        setState(() => _stato = _StatoAndroid.estrazione);
        final jsonRaw = await AndroidImportService.estraiTesto(images);
        _analizzaJson(jsonRaw);
      } else {
        // Niente AICore: vai direttamente all'inserimento manuale
        setState(() {
          _valoriEstratti = [];
          _dataEsame = null;
          _stato = _StatoAndroid.anteprima;
        });
      }
    } on AndroidImportException catch (e) {
      setState(() {
        _errore = e.messaggio;
        _stato = _StatoAndroid.errore;
      });
    } catch (e) {
      setState(() {
        _errore = 'Errore inatteso: $e';
        _stato = _StatoAndroid.errore;
      });
    }
  }

  void _analizzaJson(String jsonRaw) {
    try {
      // Riutilizza il parser già esistente in VisionRepository (tollerante
      // a code fence, testo attorno, virgole decimali italiane ecc.).
      final risultato = VisionRepository.parseRisposta(jsonRaw);
      setState(() {
        _valoriEstratti = risultato.valori;
        _dataEsame = risultato.data;
        _stato = _StatoAndroid.anteprima;
      });
    } catch (_) {
      setState(() {
        _valoriEstratti = [];
        _dataEsame = null;
        _stato = _StatoAndroid.anteprima;
      });
    }
  }

  void _reset() {
    setState(() {
      _stato = _StatoAndroid.inAttesa;
      _errore = null;
      _base64Images = [];
      _valoriEstratti = [];
      _dataEsame = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      titolo: 'Import',
      body: Column(
        children: [
          // Banner Gemini Nano non disponibile
          if (_aiCoreDisponibile == false)
            _BannerFallback(),

          Expanded(
            child: switch (_stato) {
              _StatoAndroid.inAttesa => _InAttivaAndroid(
                onAvvia: _avviaFlusso,
                aiCoreOk: _aiCoreDisponibile,
              ),
              _StatoAndroid.scansione => const _InCorso(
                messaggio: 'Avvio scanner…',
              ),
              _StatoAndroid.estrazione => const _InCorso(
                messaggio: 'Gemini Nano sta analizzando il referto…',
              ),
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
                      Text(_errore ?? 'Errore sconosciuto',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      AdaptiveButton(
                        etichetta: 'Riprova',
                        icona: Icons.refresh,
                        onPressed: _avviaFlusso,
                      ),
                    ],
                  ),
                ),
              ),
              _StatoAndroid.anteprima => Consumer(
                builder: (ctx, ref, _) => TabellaValoriEditor(
                  key: ValueKey(Object.hashAll(_valoriEstratti)),
                  valoriIniziali: _valoriEstratti,
                  avviso: _valoriEstratti.isEmpty
                      ? 'Gemini Nano non ha trovato valori — inseriscili manualmente'
                      : 'Verifica i valori estratti prima di salvare',
                  dataIniziale: _dataEsame,
                  onSalva: (valori, data) async {
                    final controller =
                        ref.read(importControllerProvider.notifier);
                    await controller.salva(valori, data);
                    if (ctx.mounted) _reset();
                  },
                  onAnnulla: _reset,
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _BannerFallback extends StatelessWidget {
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
              'Gemini Nano non disponibile su questo dispositivo — inserimento manuale',
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
  final VoidCallback onAvvia;
  final bool? aiCoreOk;

  const _InAttivaAndroid({required this.onAvvia, required this.aiCoreOk});

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final descrizione = aiCoreOk == false
        ? 'Scansiona il referto con la fotocamera e inserisci i valori manualmente'
        : 'Scansiona il referto con la fotocamera — Gemini Nano estrarrà i valori in automatico';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.document_scanner_outlined, size: 72, color: schema.primary),
            const SizedBox(height: 20),
            Text(
              'Scansiona un referto',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(descrizione,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 32),
            AdaptiveButton(
              etichetta: 'Scansiona referto',
              icona: Icons.camera_alt_outlined,
              onPressed: onAvvia,
            ),
          ],
        ),
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
