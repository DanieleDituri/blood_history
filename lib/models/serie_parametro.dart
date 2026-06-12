import 'range_riferimento.dart';

/// Un singolo punto nella serie temporale di un parametro.
class PuntoParametro {
  final DateTime data;
  final double valore;

  const PuntoParametro({required this.data, required this.valore});
}

/// Evoluzione nel tempo di un parametro: tutti i valori registrati,
/// ordinati cronologicamente (dal più vecchio al più recente).
class SerieParametro {
  final String nome;
  final String unita;

  /// Range dell'esame più recente (l'unico mostrato nella legenda).
  final RangeRiferimento range;

  /// Almeno un punto garantito; già ordinati per data crescente.
  final List<PuntoParametro> punti;

  const SerieParametro({
    required this.nome,
    required this.unita,
    required this.range,
    required this.punti,
  });

  PuntoParametro get ultimoPunto => punti.last;
}
