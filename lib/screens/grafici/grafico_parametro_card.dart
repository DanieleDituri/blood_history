import 'dart:math' show min, max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/serie_parametro.dart';

/// Grafico a linea per una singola serie temporale di parametro.
///
/// Mostra:
/// - Linea blu con punti tappabili (tooltip data + valore)
/// - Fascia verde semitrasparente tra range_min e range_max
/// - Linee tratteggiate rosse a range_min e range_max
///
/// [fullscreen] = true allarga il grafico e aggiunge i titoli dell'asse Y.
class GraficoParametroCard extends StatefulWidget {
  final SerieParametro serie;
  final VoidCallback? onTap;
  final bool fullscreen;

  const GraficoParametroCard({
    super.key,
    required this.serie,
    this.onTap,
    this.fullscreen = false,
  });

  @override
  State<GraficoParametroCard> createState() => _GraficoParametroCardState();
}

class _GraficoParametroCardState extends State<GraficoParametroCard> {
  int? _indiceToccato;

  SerieParametro get _s => widget.serie;

  /// true se esiste un range completo (entrambi min e max).
  bool get _hasBand => _s.range.min != null && _s.range.max != null;

  /// Indice nella lista lineBarsData della linea dei dati reali.
  int get _dataIdx => _hasBand ? 2 : 0;

  LineChartData _buildData(ColorScheme schema) {
    final punti = _s.punti;
    final n = punti.length;

    // X index-based: 0 … n-1 per semplicità di rendering.
    final spots = [
      for (var i = 0; i < n; i++) FlSpot(i.toDouble(), punti[i].valore),
    ];

    // Bounds Y
    double minY = punti.map((p) => p.valore).reduce(min);
    double maxY = punti.map((p) => p.valore).reduce(max);
    if (_s.range.min != null) minY = min(minY, _s.range.min!);
    if (_s.range.max != null) maxY = max(maxY, _s.range.max!);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final padY = (maxY - minY) * 0.18;

    // Barre: [rangeMin, rangeMax, dati] oppure [dati]
    final bars = <LineChartBarData>[];
    if (_hasBand) {
      bars.add(_barOrizzontale(0, n - 1, _s.range.min!));
      bars.add(_barOrizzontale(0, n - 1, _s.range.max!));
    }
    bars.add(
      LineChartBarData(
        spots: spots,
        color: schema.primary,
        barWidth: 2,
        isCurved: n > 2,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, idx) => FlDotCirclePainter(
            radius: _indiceToccato == idx ? 6 : 4,
            color: schema.primary,
            strokeWidth: 0,
          ),
        ),
      ),
    );

    final intervalloX = n <= 1
        ? 1.0
        : (n <= 4 ? 1.0 : ((n - 1) / (widget.fullscreen ? 5 : 3)).ceilToDouble());

    return LineChartData(
      minX: 0,
      maxX: (n - 1).toDouble(),
      minY: minY - padY,
      maxY: maxY + padY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: widget.fullscreen,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      betweenBarsData: _hasBand
          ? [
              BetweenBarsData(
                fromIndex: 0,
                toIndex: 1,
                color: Colors.green.withValues(alpha: 0.15),
              ),
            ]
          : [],
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          if (_s.range.min != null)
            HorizontalLine(
              y: _s.range.min!,
              color: Colors.red.withValues(alpha: 0.6),
              dashArray: [5, 4],
              strokeWidth: 1,
            ),
          if (_s.range.max != null)
            HorizontalLine(
              y: _s.range.max!,
              color: Colors.red.withValues(alpha: 0.6),
              dashArray: [5, 4],
              strokeWidth: 1,
            ),
        ],
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: widget.fullscreen,
            reservedSize: 48,
            getTitlesWidget: (value, meta) {
              if (value == meta.min || value == meta.max) {
                return const SizedBox.shrink();
              }
              return Text(
                _formatNum(value),
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.right,
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: intervalloX,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final idx = value.round();
              if (idx < 0 ||
                  idx >= n ||
                  (value - idx).abs() > 0.01) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('dd/MM/yy').format(punti[idx].data),
                  style: TextStyle(
                    fontSize: widget.fullscreen ? 11 : 9,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: bars,
      lineTouchData: LineTouchData(
        touchCallback: (event, response) {
          if (event is FlTapUpEvent) {
            setState(() {
              _indiceToccato =
                  response?.lineBarSpots?.firstOrNull?.spotIndex;
            });
          }
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.black87,
          getTooltipItems: (spots) {
            return spots.map((spot) {
              if (spot.barIndex != _dataIdx) return null;
              final idx = spot.x.round();
              if (idx < 0 || idx >= punti.length) return null;
              final p = punti[idx];
              return LineTooltipItem(
                '${DateFormat('dd/MM/yyyy').format(p.data)}\n'
                '${_formatNum(p.valore)} ${_s.unita}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.4,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  static LineChartBarData _barOrizzontale(int x0, int x1, double y) =>
      LineChartBarData(
        spots: [FlSpot(x0.toDouble(), y), FlSpot(x1.toDouble(), y)],
        color: Colors.transparent,
        dotData: const FlDotData(show: false),
      );

  static String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      child: LineChart(
        _buildData(schema),
        duration: const Duration(milliseconds: 200),
      ),
    );
  }
}

/// Header di un parametro: nome, unità, range consigliato in testo.
class HeaderGrafico extends StatelessWidget {
  final SerieParametro serie;
  final bool fullscreen;

  const HeaderGrafico({
    super.key,
    required this.serie,
    this.fullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rangeDesc = _descrizioneRange(serie);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          serie.nome,
          style: (fullscreen
                  ? tema.textTheme.titleLarge
                  : tema.textTheme.titleSmall)
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (rangeDesc != null)
          Text(
            rangeDesc,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
      ],
    );
  }

  static String? _descrizioneRange(SerieParametro s) {
    final min = s.range.min;
    final max = s.range.max;
    final u = s.unita;
    if (min != null && max != null) {
      return 'Range: ${_n(min)}–${_n(max)} $u';
    } else if (min != null) {
      return 'Min: ${_n(min)} $u';
    } else if (max != null) {
      return 'Max: ${_n(max)} $u';
    }
    return null;
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
