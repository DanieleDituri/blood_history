import 'valore_esame.dart';

/// L'ultimo valore noto di un parametro, con la data dell'esame da cui
/// proviene. È l'unità mostrata nelle card della schermata Snapshot.
class ParametroSnapshot {
  final ValoreEsame valore;
  final DateTime dataEsame;

  const ParametroSnapshot({required this.valore, required this.dataEsame});

  String get nome => valore.nome;
}
