import 'stato_valore.dart';

/// Range di riferimento di un parametro, come riportato sul referto.
///
/// Uno dei due estremi può mancare (range aperti tipo "< 200" o "> 40").
class RangeRiferimento {
  final double? min;
  final double? max;

  const RangeRiferimento({this.min, this.max});

  bool get isVuoto => min == null && max == null;

  /// Tolleranza usata per il borderline: 10% dell'ampiezza del range,
  /// oppure 10% del valore assoluto del limite quando il range è aperto.
  double _tolleranza() {
    if (min != null && max != null && max! > min!) {
      return (max! - min!) * 0.10;
    }
    final limite = (max ?? min)!.abs();
    return limite * 0.10;
  }

  /// Classifica [valore] rispetto al range:
  /// dentro il range → [StatoValore.inRange]; fuori ma entro il 10% di
  /// tolleranza dal limite violato → [StatoValore.borderline]; oltre →
  /// [StatoValore.fuoriRange]. Senza range → [StatoValore.sconosciuto].
  StatoValore statoDi(double valore) {
    if (isVuoto) return StatoValore.sconosciuto;

    final tolleranza = _tolleranza();

    if (min != null && valore < min!) {
      return valore >= min! - tolleranza
          ? StatoValore.borderline
          : StatoValore.fuoriRange;
    }
    if (max != null && valore > max!) {
      return valore <= max! + tolleranza
          ? StatoValore.borderline
          : StatoValore.fuoriRange;
    }
    return StatoValore.inRange;
  }

  /// Rappresentazione leggibile, es. "70 – 99", "< 200", "> 40".
  String get descrizione {
    if (isVuoto) return '—';
    if (min == null) return '< ${_fmt(max!)}';
    if (max == null) return '> ${_fmt(min!)}';
    return '${_fmt(min!)} – ${_fmt(max!)}';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  factory RangeRiferimento.fromJson(Map<String, dynamic> json) =>
      RangeRiferimento(
        min: (json['range_min'] as num?)?.toDouble(),
        max: (json['range_max'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {'range_min': min, 'range_max': max};

  @override
  bool operator ==(Object other) =>
      other is RangeRiferimento && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'RangeRiferimento($descrizione)';
}
