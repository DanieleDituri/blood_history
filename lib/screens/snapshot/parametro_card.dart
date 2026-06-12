import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/parametro_snapshot.dart';
import '../../ui/platform/adaptive_card.dart';

/// Card di un singolo parametro nella griglia Snapshot: nome, ultimo
/// valore con unità, range di riferimento, data dell'esame e indicatore
/// colorato dello stato (verde / giallo / rosso).
class ParametroCard extends StatelessWidget {
  final ParametroSnapshot parametro;
  final VoidCallback? onTap;

  const ParametroCard({super.key, required this.parametro, this.onTap});

  static final _formatoData = DateFormat('dd/MM/yyyy');

  String _formattaValore(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final valore = parametro.valore;
    final stato = valore.stato;

    return AdaptiveCard(
      onTap: onTap,
      child: Stack(
        children: [
          // Barra laterale colorata con lo stato.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 5, color: stato.colore),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        valore.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.titleSmall,
                      ),
                    ),
                    Tooltip(
                      message: stato.etichetta,
                      child: Icon(Icons.circle, size: 12, color: stato.colore),
                    ),
                  ],
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    text: _formattaValore(valore.valore),
                    style: tema.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: stato.colore,
                    ),
                    children: [
                      TextSpan(
                        text: ' ${valore.unita}',
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Range: ${valore.range.descrizione}',
                  style: tema.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatoData.format(parametro.dataEsame),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
