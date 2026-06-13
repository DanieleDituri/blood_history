import 'package:esami_tracker/ui/platform/adaptive_button.dart';
import 'package:esami_tracker/ui/platform/adaptive_card.dart';
import 'package:esami_tracker/ui/platform/adaptive_navigation.dart';
import 'package:esami_tracker/ui/platform/adaptive_platform.dart';
import 'package:esami_tracker/ui/platform/adaptive_scaffold.dart';
import 'package:esami_tracker/ui/platform/adaptive_theme.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Verifica che ogni wrapper Adaptive* costruisca il widget giusto per
/// la piattaforma forzata con [AdaptivePlatform.debugOverride].
void main() {
  tearDown(() => AdaptivePlatform.debugOverride = null);

  /// Pompa [widget] dentro l'app adattiva della piattaforma corrente,
  /// così i wrapper trovano il Theme/FluentTheme che avrebbero a runtime.
  Future<void> pompa(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(AdaptiveApp(titolo: 'Test', home: widget));
    await tester.pump();
  }

  group('AdaptiveApp', () {
    testWidgets('Android → MaterialApp', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.android;
      await pompa(tester, const SizedBox());
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(fluent.FluentApp), findsNothing);
    });

    testWidgets('macOS → MaterialApp come base', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.macos;
      await pompa(tester, const SizedBox());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Windows → FluentApp', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.windows;
      await pompa(tester, const SizedBox());
      expect(find.byType(fluent.FluentApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing);
    });
  });

  group('AdaptiveCard', () {
    const card = AdaptiveCard(child: Text('contenuto'));

    testWidgets('Android → Card Material', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.android;
      await pompa(tester, const Scaffold(body: card));
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text('contenuto'), findsOneWidget);
    });

    testWidgets('macOS → GlassContainer', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.macos;
      await pompa(tester, const Scaffold(body: card));
      expect(find.byType(GlassContainer), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('contenuto'), findsOneWidget);
    });

    testWidgets('Windows → Acrylic', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.windows;
      await pompa(tester, card);
      expect(find.byType(fluent.Acrylic), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('contenuto'), findsOneWidget);
    });
  });

  group('AdaptiveScaffold', () {
    const scaffold = AdaptiveScaffold(titolo: 'Titolo', body: Text('corpo'));

    testWidgets('Android → Scaffold + AppBar', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.android;
      await pompa(tester, scaffold);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('corpo'), findsOneWidget);
    });

    testWidgets('macOS → Scaffold trasparente su gradiente', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.macos;
      await pompa(tester, scaffold);
      final s = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(s.backgroundColor, Colors.transparent);
      expect(find.text('corpo'), findsOneWidget);
    });

    testWidgets('Windows → ScaffoldPage Fluent', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.windows;
      await pompa(tester, scaffold);
      expect(find.byType(fluent.ScaffoldPage), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('corpo'), findsOneWidget);
    });
  });

  group('AdaptiveNavigation', () {
    final navigazione = AdaptiveNavigation(
      indiceSelezionato: 0,
      onDestinazioneSelezionata: (_) {},
      destinazioni: const [
        DestinazioneAdaptive(
          icona: Icons.home_outlined,
          iconaAttiva: Icons.home,
          etichetta: 'Home',
        ),
        DestinazioneAdaptive(
          icona: Icons.settings_outlined,
          iconaAttiva: Icons.settings,
          etichetta: 'Altro',
        ),
      ],
      schermate: const [Text('pagina 1'), Text('pagina 2')],
    );

    testWidgets('Android → NavigationBar in basso', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.android;
      await pompa(tester, navigazione);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('pagina 1'), findsOneWidget);
    });

    testWidgets('macOS → sidebar sinistra, niente NavigationBar', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.macos;
      await pompa(tester, navigazione);
      // La sidebar macOS è un Container generico: verifichiamo che NON ci
      // sia la NavigationBar Material (è rimpiazzata dalla sidebar custom).
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('pagina 1'), findsOneWidget);
    });

    testWidgets('Windows → NavigationView laterale, niente bottom bar', (
      tester,
    ) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.windows;
      await pompa(tester, navigazione);
      expect(find.byType(fluent.NavigationView), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('AdaptiveButton / AdaptiveIconButton', () {
    testWidgets('Android → FilledButton e IconButton Material', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.android;
      await pompa(
        tester,
        Scaffold(
          body: Column(
            children: [
              AdaptiveButton(etichetta: 'Azione', onPressed: () {}),
              AdaptiveIconButton(icona: Icons.refresh, onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('macOS → superfici glass', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.macos;
      await pompa(
        tester,
        Scaffold(
          body: Column(
            children: [
              AdaptiveButton(etichetta: 'Azione', onPressed: () {}),
              AdaptiveIconButton(icona: Icons.refresh, onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.byType(GlassContainer), findsOneWidget); // pillola bottone
      // Icon button ora usa _MacosIconButton (borderless native-style)
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('Windows → bottoni Fluent', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.windows;
      await pompa(
        tester,
        Column(
          children: [
            AdaptiveButton(etichetta: 'Azione', onPressed: () {}),
            AdaptiveIconButton(icona: Icons.refresh, onPressed: () {}),
          ],
        ),
      );
      expect(find.byType(fluent.FilledButton), findsOneWidget);
      expect(find.byType(fluent.IconButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('il tap su AdaptiveButton arriva al callback', (tester) async {
      AdaptivePlatform.debugOverride = PiattaformaApp.android;
      var premuto = false;
      await pompa(
        tester,
        Scaffold(
          body: AdaptiveButton(
            etichetta: 'Azione',
            onPressed: () => premuto = true,
          ),
        ),
      );
      await tester.tap(find.text('Azione'));
      expect(premuto, isTrue);
    });
  });
}
