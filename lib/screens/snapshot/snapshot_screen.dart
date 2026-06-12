import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/parametro_snapshot.dart';
import '../../providers/providers.dart';
import '../../ui/platform/adaptive_button.dart';
import '../../ui/platform/adaptive_scaffold.dart';
import 'parametro_card.dart';

/// Griglia con l'ultimo valore noto di ogni parametro.
class SnapshotScreen extends ConsumerWidget {
  const SnapshotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(snapshotProvider);

    return AdaptiveScaffold(
      titolo: 'Snapshot',
      azioni: [
        AdaptiveIconButton(
          tooltip: 'Aggiorna',
          icona: Icons.refresh,
          onPressed: () => ref.invalidate(snapshotProvider),
        ),
      ],
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (errore, _) => _MessaggioErrore(
          errore: errore,
          onRiprova: () => ref.invalidate(snapshotProvider),
        ),
        data: (parametri) => parametri.isEmpty
            ? const _NessunDato()
            : _GrigliaParametri(parametri: parametri),
      ),
    );
  }
}

class _GrigliaParametri extends StatelessWidget {
  final List<ParametroSnapshot> parametri;

  const _GrigliaParametri({required this.parametri});

  @override
  Widget build(BuildContext context) {
    final piuRecente = parametri
        .map((p) => p.dataEsame)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Ultimo esame: ${DateFormat('dd MMMM yyyy', 'it').format(piuRecente)}'
            ' · ${parametri.length} parametri',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            // Il padding inferiore include la safe area: su macOS è la
            // barra glass flottante, e la griglia ci scorre sotto.
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              // Responsive: il numero di colonne segue la larghezza
              // disponibile (telefono ~2, desktop 4+).
              maxCrossAxisExtent: 230,
              mainAxisExtent: 150,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: parametri.length,
            itemBuilder: (context, i) => ParametroCard(parametro: parametri[i]),
          ),
        ),
      ],
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
            Icons.science_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('Nessun esame in archivio'),
          const SizedBox(height: 4),
          Text(
            'Importa il tuo primo referto dalla scheda Import',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MessaggioErrore extends StatelessWidget {
  final Object errore;
  final VoidCallback onRiprova;

  const _MessaggioErrore({required this.errore, required this.onRiprova});

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
            Text(
              'Errore nel caricamento: $errore',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            AdaptiveButton(
              etichetta: 'Riprova',
              icona: Icons.refresh,
              onPressed: onRiprova,
            ),
          ],
        ),
      ),
    );
  }
}
