import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/serie_parametro.dart';
import '../../providers/providers.dart';
import '../../ui/platform/adaptive_button.dart';
import '../../ui/platform/adaptive_scaffold.dart';
import 'grafico_fullscreen.dart';
import 'grafico_parametro_card.dart';

/// Lista scrollabile di tutti i parametri mai registrati, ognuno con
/// il proprio grafico fl_chart. Tap → schermo intero.
class GraficiScreen extends ConsumerWidget {
  const GraficiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grafici = ref.watch(graficiProvider);

    return AdaptiveScaffold(
      titolo: 'Grafici',
      azioni: [
        AdaptiveIconButton(
          tooltip: 'Aggiorna',
          icona: Icons.refresh,
          onPressed: () => ref.invalidate(graficiProvider),
        ),
      ],
      body: grafici.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Errore(
          errore: e,
          onRiprova: () => ref.invalidate(graficiProvider),
        ),
        data: (serie) => serie.isEmpty
            ? const _NessunDato()
            : _ListaGrafici(serie: serie),
      ),
    );
  }
}

class _ListaGrafici extends StatelessWidget {
  final List<SerieParametro> serie;

  const _ListaGrafici({required this.serie});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: serie.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _CardGrafico(serie: serie[i]),
    );
  }
}

class _CardGrafico extends StatelessWidget {
  final SerieParametro serie;

  const _CardGrafico({required this.serie});

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: schema.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => GraficoFullscreen.apri(context, serie),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: HeaderGrafico(serie: serie)),
                  Icon(
                    Icons.open_in_full,
                    size: 16,
                    color: schema.outline,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: GraficoParametroCard(
                  serie: serie,
                  onTap: () => GraficoFullscreen.apri(context, serie),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NessunDato extends StatelessWidget {
  const _NessunDato();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('Nessun grafico disponibile'),
          const SizedBox(height: 4),
          Text(
            'Importa almeno un referto dalla scheda Import',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Errore extends StatelessWidget {
  final Object errore;
  final VoidCallback onRiprova;

  const _Errore({required this.errore, required this.onRiprova});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text('Errore: $errore', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRiprova,
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}
