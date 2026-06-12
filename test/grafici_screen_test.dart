import 'package:esami_tracker/models/range_riferimento.dart';
import 'package:esami_tracker/models/serie_parametro.dart';
import 'package:esami_tracker/providers/providers.dart';
import 'package:esami_tracker/screens/grafici/grafici_screen.dart';
import 'package:esami_tracker/screens/grafici/grafico_parametro_card.dart';
import 'package:esami_tracker/ui/platform/adaptive_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Dati mock multi-data ---------------------------------------------------

final _punti3 = [
  PuntoParametro(data: DateTime(2025, 11, 3), valore: 92),
  PuntoParametro(data: DateTime(2026, 2, 10), valore: 96),
  PuntoParametro(data: DateTime(2026, 5, 12), valore: 101),
];

final _serieGlicemia = SerieParametro(
  nome: 'Glicemia',
  unita: 'mg/dL',
  range: const RangeRiferimento(min: 70, max: 99),
  punti: _punti3,
);

final _serieSingola = SerieParametro(
  nome: 'TSH',
  unita: 'µUI/mL',
  range: const RangeRiferimento(min: 0.4, max: 4.0),
  punti: [PuntoParametro(data: DateTime(2026, 5, 12), valore: 2.1)],
);

final _serieSenzaRange = SerieParametro(
  nome: 'Vitamina B12',
  unita: 'pg/mL',
  range: const RangeRiferimento(),
  punti: [
    PuntoParametro(data: DateTime(2025, 11, 3), valore: 320),
    PuntoParametro(data: DateTime(2026, 5, 12), valore: 410),
  ],
);

final _mockSerie = [_serieGlicemia, _serieSingola, _serieSenzaRange];

// ---- Helper di pump ---------------------------------------------------------

Widget _wrapGrafici({List<SerieParametro>? serie}) {
  return ProviderScope(
    overrides: [
      graficiProvider.overrideWith(
        (ref) async => serie ?? _mockSerie,
      ),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) {
          AdaptivePlatform.debugOverride = PiattaformaApp.android;
          return const GraficiScreen();
        },
      ),
    ),
  );
}

// ---- Test -------------------------------------------------------------------

void main() {
  setUpAll(() {
    AdaptivePlatform.debugOverride = PiattaformaApp.android;
  });

  tearDownAll(() {
    AdaptivePlatform.debugOverride = null;
  });

  testWidgets('mostra titolo Grafici', (tester) async {
    await tester.pumpWidget(_wrapGrafici());
    await tester.pumpAndSettle();
    expect(find.text('Grafici'), findsWidgets);
  });

  testWidgets('mostra una card per ogni parametro', (tester) async {
    await tester.pumpWidget(_wrapGrafici());
    await tester.pumpAndSettle();
    expect(find.text('Glicemia'), findsWidgets);
    expect(find.text('TSH'), findsWidgets);
    expect(find.text('Vitamina B12'), findsWidgets);
  });

  testWidgets('mostra header con range per Glicemia', (tester) async {
    await tester.pumpWidget(_wrapGrafici());
    await tester.pumpAndSettle();
    // Il testo "Range: 70–99 mg/dL" deve essere visibile
    expect(
      find.textContaining('Range: 70'),
      findsWidgets,
    );
  });

  testWidgets('parametro con un solo punto non crasha', (tester) async {
    await tester.pumpWidget(_wrapGrafici(serie: [_serieSingola]));
    await tester.pumpAndSettle();
    expect(find.text('TSH'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parametro senza range non crasha', (tester) async {
    await tester.pumpWidget(_wrapGrafici(serie: [_serieSenzaRange]));
    await tester.pumpAndSettle();
    expect(find.text('Vitamina B12'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schermata vuota mostra messaggio nessun dato', (tester) async {
    await tester.pumpWidget(_wrapGrafici(serie: []));
    await tester.pumpAndSettle();
    expect(find.text('Nessun grafico disponibile'), findsOneWidget);
  });

  testWidgets('GraficoParametroCard render con 3 punti', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: GraficoParametroCard(serie: _serieGlicemia),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('GraficoParametroCard render con un punto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: GraficoParametroCard(serie: _serieSingola),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('HeaderGrafico mostra range testuale corretto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeaderGrafico(serie: _serieGlicemia),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Glicemia'), findsOneWidget);
    expect(find.textContaining('70'), findsWidgets);
    expect(find.textContaining('99'), findsWidgets);
  });

  testWidgets('HeaderGrafico senza range non mostra testo range', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeaderGrafico(serie: _serieSenzaRange),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Range:'), findsNothing);
  });
}
