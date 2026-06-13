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
    // ListView.builder è lazy: costruisce solo le card visibili a schermo.
    // Le card usano AutomaticKeepAlive per mantenere il grafico in memoria
    // quando scorrono fuori dalla viewport (evita rebuilds costosi).
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: serie.length * 2 - 1,
      itemBuilder: (context, i) {
        if (i.isOdd) return const SizedBox(height: 12);
        return _CardGrafico(serie: serie[i ~/ 2]);
      },
    );
  }
}

/// Card con grafico. Usa [AutomaticKeepAliveClientMixin] per conservare
/// in memoria il grafico anche quando la card scorre fuori dalla viewport:
/// evita di ricostruire LineChart ogni volta che l'utente scorre avanti e
/// indietro.
class _CardGrafico extends StatefulWidget {
  final SerieParametro serie;

  const _CardGrafico({required this.serie});

  @override
  State<_CardGrafico> createState() => _CardGraficoState();
}

class _CardGraficoState extends State<_CardGrafico>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // richiesto da AutomaticKeepAliveClientMixin
    final schema = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: schema.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => GraficoFullscreen.apri(context, widget.serie),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: HeaderGrafico(serie: widget.serie)),
                  Icon(Icons.open_in_full, size: 16, color: schema.outline),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: GraficoParametroCard(
                  serie: widget.serie,
                  onTap: () => GraficoFullscreen.apri(context, widget.serie),
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
