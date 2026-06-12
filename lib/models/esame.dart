import 'valore_esame.dart';

/// Un referto completo: la data del prelievo e tutti i valori estratti.
///
/// Su Drive ogni esame è salvato come `data/YYYY-MM-DD.json` più il PDF
/// originale in `pdf/`.
class Esame {
  final DateTime data;
  final List<ValoreEsame> valori;
  final String? laboratorio;

  /// ID dei file su Google Drive, valorizzati dopo l'upload o la sync.
  final String? pdfDriveId;
  final String? jsonDriveId;

  Esame({
    required DateTime data,
    required this.valori,
    this.laboratorio,
    this.pdfDriveId,
    this.jsonDriveId,
  }) : data = DateTime(data.year, data.month, data.day);

  /// Nome file canonico su Drive: `YYYY-MM-DD.json`.
  String get nomeFileJson => '$dataIso.json';

  /// Data in formato ISO `YYYY-MM-DD` (chiave naturale dell'esame).
  String get dataIso =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  ValoreEsame? valorePerNome(String nome) {
    final n = nome.toLowerCase();
    for (final v in valori) {
      if (v.nome.toLowerCase() == n) return v;
    }
    return null;
  }

  factory Esame.fromJson(Map<String, dynamic> json) => Esame(
    data: DateTime.parse(json['data'] as String),
    laboratorio: json['laboratorio'] as String?,
    valori: (json['valori'] as List<dynamic>? ?? const [])
        .map((v) => ValoreEsame.fromJson(v as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'data': dataIso,
    if (laboratorio != null) 'laboratorio': laboratorio,
    'valori': valori.map((v) => v.toJson()).toList(),
  };

  Esame copyWith({
    DateTime? data,
    List<ValoreEsame>? valori,
    String? laboratorio,
    String? pdfDriveId,
    String? jsonDriveId,
  }) => Esame(
    data: data ?? this.data,
    valori: valori ?? this.valori,
    laboratorio: laboratorio ?? this.laboratorio,
    pdfDriveId: pdfDriveId ?? this.pdfDriveId,
    jsonDriveId: jsonDriveId ?? this.jsonDriveId,
  );

  @override
  String toString() => 'Esame($dataIso, ${valori.length} valori)';
}
