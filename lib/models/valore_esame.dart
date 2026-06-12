import 'range_riferimento.dart';
import 'stato_valore.dart';

/// Singolo valore estratto da un referto: un parametro con il suo
/// valore numerico, unità di misura e range di riferimento del laboratorio.
class ValoreEsame {
  final String nome;
  final double valore;
  final String unita;
  final RangeRiferimento range;

  const ValoreEsame({
    required this.nome,
    required this.valore,
    required this.unita,
    this.range = const RangeRiferimento(),
  });

  StatoValore get stato => range.statoDi(valore);

  factory ValoreEsame.fromJson(Map<String, dynamic> json) => ValoreEsame(
    nome: json['nome'] as String,
    valore: (json['valore'] as num).toDouble(),
    unita: json['unita'] as String? ?? '',
    range: RangeRiferimento.fromJson(json),
  );

  /// JSON piatto (range_min/range_max al livello del valore), nello stesso
  /// formato prodotto dal modello vision in fase di estrazione.
  Map<String, dynamic> toJson() => {
    'nome': nome,
    'valore': valore,
    'unita': unita,
    ...range.toJson(),
  };

  ValoreEsame copyWith({
    String? nome,
    double? valore,
    String? unita,
    RangeRiferimento? range,
  }) => ValoreEsame(
    nome: nome ?? this.nome,
    valore: valore ?? this.valore,
    unita: unita ?? this.unita,
    range: range ?? this.range,
  );

  @override
  bool operator ==(Object other) =>
      other is ValoreEsame &&
      other.nome == nome &&
      other.valore == valore &&
      other.unita == unita &&
      other.range == range;

  @override
  int get hashCode => Object.hash(nome, valore, unita, range);

  @override
  String toString() =>
      'ValoreEsame($nome: $valore $unita, ${range.descrizione})';
}
