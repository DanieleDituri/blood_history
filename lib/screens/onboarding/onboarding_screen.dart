import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/costanti.dart';
import '../../providers/providers.dart';
import '../home_shell.dart';

/// Wizard di primo avvio — mostrato una sola volta.
///
/// Step 1: configura endpoint modello locale (saltabile)
/// Step 2: importa il tuo primo esame
///
/// Google Drive si collega facoltativamente nelle Impostazioni.
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Barra di avanzamento
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
                children: [
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
          'prima del salvataggio.\n\nPuoi collegare Google Drive facoltativamente '
          'dalle Impostazioni per fare backup automatico.',
      azioni: FilledButton(
        onPressed: onFine,
        child: const Text("Inizia a usare l'app"),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
        ],
      ),
    );
  }
}
