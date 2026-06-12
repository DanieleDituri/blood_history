import 'package:flutter/material.dart';

import '../../models/serie_parametro.dart';
import 'grafico_parametro_card.dart';

/// Vista a schermo intero di un singolo parametro, aperta con [apri].
class GraficoFullscreen extends StatelessWidget {
  final SerieParametro serie;

  const GraficoFullscreen({super.key, required this.serie});

  static Future<void> apri(BuildContext context, SerieParametro serie) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => GraficoFullscreen(serie: serie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(serie.nome),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderGrafico(serie: serie, fullscreen: true),
            const SizedBox(height: 4),
            _Legenda(serie: serie),
            const SizedBox(height: 16),
            Expanded(
              child: GraficoParametroCard(serie: serie, fullscreen: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final SerieParametro serie;

  const _Legenda({required this.serie});

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        _chip(schema.primary, 'Valore misurato'),
        if (serie.range.min != null || serie.range.max != null) ...[
          _chip(Colors.green.withValues(alpha: 0.6), 'Range normale'),
          _chip(Colors.red.withValues(alpha: 0.7), 'Limite (tratteggio)'),
        ],
      ],
    );
  }

  static Widget _chip(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  );
}
