import 'package:esami_tracker/models/parametro_snapshot.dart';
import 'package:esami_tracker/models/range_riferimento.dart';
import 'package:esami_tracker/models/stato_valore.dart';
import 'package:esami_tracker/models/valore_esame.dart';
import 'package:esami_tracker/screens/snapshot/parametro_card.dart';
import 'package:esami_tracker/ui/platform/adaptive_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Piattaforma fissa: questo test verifica il contenuto della card,
  // non la superficie adattiva (coperta da adaptive_ui_test.dart).
  setUp(() => AdaptivePlatform.debugOverride = PiattaformaApp.android);
  tearDown(() => AdaptivePlatform.debugOverride = null);

  Widget app(ParametroSnapshot parametro) => MaterialApp(
    home: Scaffold(body: ParametroCard(parametro: parametro)),
  );

  testWidgets('ParametroCard mostra nome, valore, range e data', (
    tester,
  ) async {
    final parametro = ParametroSnapshot(
      valore: const ValoreEsame(
        nome: 'Glicemia',
        valore: 92,
        unita: 'mg/dL',
        range: RangeRiferimento(min: 70, max: 99),
      ),
      dataEsame: DateTime(2026, 5, 12),
    );

    await tester.pumpWidget(app(parametro));

    expect(find.text('Glicemia'), findsOneWidget);
    expect(find.textContaining('92'), findsOneWidget);
    expect(find.text('Range: 70 – 99'), findsOneWidget);
    expect(find.text('12/05/2026'), findsOneWidget);
  });

  testWidgets('l\'indicatore usa il colore dello stato fuori range', (
    tester,
  ) async {
    final parametro = ParametroSnapshot(
      valore: const ValoreEsame(
        nome: 'Colesterolo LDL',
        valore: 158,
        unita: 'mg/dL',
        range: RangeRiferimento(max: 130),
      ),
      dataEsame: DateTime(2026, 5, 12),
    );

    await tester.pumpWidget(app(parametro));

    final indicatore = tester.widget<Icon>(find.byIcon(Icons.circle));
    expect(indicatore.color, StatoValore.fuoriRange.colore);
  });
}
