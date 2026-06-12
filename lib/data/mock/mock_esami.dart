import '../../models/esame.dart';
import '../../models/range_riferimento.dart';
import '../../models/valore_esame.dart';

/// Dati finti realistici usati finché l'Import (Sessione 2) non è pronto.
///
/// Tre referti su sei mesi, con i 15 parametri tipici; alcuni valori sono
/// volutamente borderline o fuori range per esercitare i colori delle card.
class MockEsami {
  MockEsami._();

  static ValoreEsame _v(
    String nome,
    double valore,
    String unita, {
    double? min,
    double? max,
  }) => ValoreEsame(
    nome: nome,
    valore: valore,
    unita: unita,
    range: RangeRiferimento(min: min, max: max),
  );

  static final List<Esame> esami = [
    Esame(
      data: DateTime(2026, 5, 12),
      laboratorio: 'Laboratorio Analisi S. Chiara',
      valori: [
        _v('Glicemia', 101, 'mg/dL', min: 70, max: 99), // borderline
        _v('Colesterolo Totale', 215, 'mg/dL', max: 200), // borderline
        _v('Colesterolo LDL', 158, 'mg/dL', max: 130), // fuori range
        _v('Colesterolo HDL', 55, 'mg/dL', min: 40),
        _v('Trigliceridi', 98, 'mg/dL', max: 150),
        _v('Ferritina', 85, 'ng/mL', min: 30, max: 400),
        _v('Emoglobina', 14.8, 'g/dL', min: 13.5, max: 17.5),
        _v('Ematocrito', 44.5, '%', min: 41, max: 53),
        _v('Piastrine', 240, 'x10³/µL', min: 150, max: 450),
        _v('Leucociti', 6.2, 'x10³/µL', min: 4, max: 10),
        _v('Creatinina', 1.0, 'mg/dL', min: 0.7, max: 1.2),
        _v('ALT', 35, 'U/L', max: 41),
        _v('AST', 28, 'U/L', max: 40),
        _v('TSH', 2.1, 'µUI/mL', min: 0.4, max: 4),
        _v('Vitamina D', 24, 'ng/mL', min: 30, max: 100), // borderline
      ],
    ),
    Esame(
      data: DateTime(2026, 2, 10),
      laboratorio: 'Laboratorio Analisi S. Chiara',
      valori: [
        _v('Glicemia', 96, 'mg/dL', min: 70, max: 99),
        _v('Colesterolo Totale', 198, 'mg/dL', max: 200),
        _v('Colesterolo LDL', 132, 'mg/dL', max: 130),
        _v('Colesterolo HDL', 52, 'mg/dL', min: 40),
        _v('Trigliceridi', 110, 'mg/dL', max: 150),
        _v('Emoglobina', 15.1, 'g/dL', min: 13.5, max: 17.5),
        _v('Ematocrito', 45.2, '%', min: 41, max: 53),
        _v('Piastrine', 255, 'x10³/µL', min: 150, max: 450),
        _v('Leucociti', 5.8, 'x10³/µL', min: 4, max: 10),
        _v('Creatinina', 0.95, 'mg/dL', min: 0.7, max: 1.2),
        _v('TSH', 2.4, 'µUI/mL', min: 0.4, max: 4),
        _v('Vitamina D', 19, 'ng/mL', min: 30, max: 100), // fuori range
      ],
    ),
    Esame(
      data: DateTime(2025, 11, 3),
      laboratorio: 'Centro Diagnostico Italiano',
      valori: [
        _v('Glicemia', 92, 'mg/dL', min: 70, max: 99),
        _v('Colesterolo Totale', 190, 'mg/dL', max: 200),
        _v('Ferritina', 72, 'ng/mL', min: 30, max: 400),
        _v('Emoglobina', 14.9, 'g/dL', min: 13.5, max: 17.5),
        _v('ALT', 44, 'U/L', max: 41), // borderline
        _v('AST', 31, 'U/L', max: 40),
        _v('TSH', 2.7, 'µUI/mL', min: 0.4, max: 4),
      ],
    ),
  ];
}
