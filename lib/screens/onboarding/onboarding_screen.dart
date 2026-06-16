import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/costanti.dart';
import '../../providers/providers.dart';
import '../home_shell.dart';

/// Wizard di primo avvio — mostrato una sola volta.
///
/// Non-Android: step 1 configura endpoint modello locale, step 2 import.
/// Android:     step 1 scelta modalità estrazione (OCR / LLM), step 2 import.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _pagina = 0;
  static const _totale = 2;

  void _avanti() {
    if (_pagina < _totale - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completa();
    }
  }

  Future<void> _completa() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Costanti.prefOnboardingCompletato, true);
    ref.invalidate(primoAvvioProvider);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _totale; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        decoration: BoxDecoration(
                          color: i <= _pagina
                              ? schema.primary
                              : schema.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (p) => setState(() => _pagina = p),
                children: isAndroid
                    ? [
                        _PaginaModalitaAndroid(onContinua: _avanti),
                        _PaginaImport(onFine: _completa),
                      ]
                    : [
                        _PaginaModello(onContinua: _avanti),
                        _PaginaImport(onFine: _completa),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Pagine -----------------------------------------------------------------

class _PaginaModello extends StatelessWidget {
  final VoidCallback onContinua;

  const _PaginaModello({required this.onContinua});

  @override
  Widget build(BuildContext context) {
    return _PaginaTemplate(
      icona: Icons.psychology_outlined,
      titolo: 'Modello AI Locale',
      descrizione:
          'EsamiTracker usa un modello vision in locale — LM Studio o Ollama '
          '— per estrarre automaticamente i valori dai PDF.\n\n'
          'Se non hai un modello installato, potrai inserire '
          'i valori a mano o configurarlo in seguito dalle Impostazioni.',
      azioni: Column(
        children: [
          FilledButton(
            onPressed: onContinua,
            child: const Text('Ho già un modello installato'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onContinua,
            child: const Text('Configura dopo'),
          ),
        ],
      ),
    );
  }
}

class _PaginaModalitaAndroid extends StatelessWidget {
  final VoidCallback onContinua;

  const _PaginaModalitaAndroid({required this.onContinua});

  Future<void> _scegli(String modalita) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Costanti.prefModalitaAndroid, modalita);
    onContinua();
  }

  @override
  Widget build(BuildContext context) {
    return _PaginaTemplate(
      icona: Icons.document_scanner_outlined,
      titolo: 'Estrazione valori',
      descrizione: 'Come vuoi che l\'app estragga i valori '
          'dai referti scansionati?',
      azioni: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardScelta(
            icona: Icons.text_fields_outlined,
            titolo: 'Solo OCR',
            sottotitolo:
                'Riconoscimento testo on-device.\n'
                'Veloce, funziona offline, nessun download.',
            onTap: () => _scegli('ocr'),
          ),
          const SizedBox(height: 12),
          _CardScelta(
            icona: Icons.psychology_outlined,
            titolo: 'LLM Gemma 2B',
            sottotitolo:
                'IA on-device — estrazione più accurata.\n'
                'Richiede ~1.5 GB da scaricare (puoi farlo dopo).',
            onTap: () => _scegli('llm'),
          ),
        ],
      ),
    );
  }
}

class _PaginaImport extends StatelessWidget {
  final VoidCallback onFine;

  const _PaginaImport({required this.onFine});

  @override
  Widget build(BuildContext context) {
    return _PaginaTemplate(
      icona: Icons.upload_file_outlined,
      titolo: 'Importa il tuo primo referto',
      descrizione:
          'Vai nella scheda Import e trascina (o seleziona) il PDF del tuo '
          'referto.\n\nIl modello lo analizzerà e potrai correggere i valori '
          'prima del salvataggio.\n\nDalle Impostazioni puoi scegliere una cartella '
          'locale per il backup automatico dei tuoi esami.',
      azioni: FilledButton(
        onPressed: onFine,
        child: const Text("Inizia a usare l'app"),
      ),
    );
  }
}

// ---- Card scelta modalità ---------------------------------------------------

class _CardScelta extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String sottotitolo;
  final VoidCallback onTap;

  const _CardScelta({
    required this.icona,
    required this.titolo,
    required this.sottotitolo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: schema.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icona, color: schema.primary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sottotitolo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: schema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: schema.outline),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Template pagina --------------------------------------------------------

class _PaginaTemplate extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String descrizione;
  final Widget azioni;

  const _PaginaTemplate({
    required this.icona,
    required this.titolo,
    required this.descrizione,
    required this.azioni,
  });

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Icon(icona, size: 72, color: schema.primary),
          const SizedBox(height: 28),
          Text(
            titolo,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            descrizione,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: schema.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          azioni,
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
