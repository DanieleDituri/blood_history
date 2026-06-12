import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// Temi per piattaforma del design system adattivo.
class AdaptiveTheme {
  AdaptiveTheme._();

  /// Seed usato quando i colori dinamici non sono disponibili.
  static const seedColor = Color(0xFFB71C1C);

  /// Tema Material (Android e macOS). Su Android [dinamico] arriva dal
  /// wallpaper (Material You); altrove o in fallback si usa il seed.
  static ThemeData material(Brightness brightness, {ColorScheme? dinamico}) {
    final schema =
        dinamico ??
        ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
    return ThemeData(colorScheme: schema, useMaterial3: true);
  }

  /// Variante macOS: superfici leggermente trasparenti così il liquid
  /// glass ha qualcosa da rifrangere.
  static ThemeData materialMacos(Brightness brightness) {
    final base = material(brightness);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  /// Tema Fluent (Windows).
  static fluent.FluentThemeData fluentTheme(Brightness brightness) =>
      fluent.FluentThemeData(
        brightness: brightness,
        accentColor: fluent.Colors.red,
        visualDensity: fluent.VisualDensity.standard,
      );
}

/// Radice dell'app: sceglie l'`*App` giusta per la piattaforma.
///
/// - **Android** — [MaterialApp] con dynamic color (Material You) e
///   fallback al seed.
/// - **macOS** — [MaterialApp] come base, con tema predisposto per le
///   superfici liquid glass.
/// - **Windows** — [fluent.FluentApp]; un `builder` inserisce un ponte
///   Material (Theme + Material trasparente + localizzazioni) così i
///   widget Material usati DENTRO le schermate continuano a funzionare.
class AdaptiveApp extends StatelessWidget {
  final String titolo;
  final Widget home;

  const AdaptiveApp({super.key, required this.titolo, required this.home});

  @override
  Widget build(BuildContext context) {
    return switch (AdaptivePlatform.corrente) {
      PiattaformaApp.android => _materialYouApp(),
      PiattaformaApp.macos => _macosApp(),
      PiattaformaApp.windows => _fluentApp(),
    };
  }

  Widget _materialYouApp() {
    return FutureBuilder<ColorScheme?>(
      future: _schemaDinamico(Brightness.light),
      builder: (context, chiaro) => FutureBuilder<ColorScheme?>(
        future: _schemaDinamico(Brightness.dark),
        builder: (context, scuro) => MaterialApp(
          title: titolo,
          debugShowCheckedModeBanner: false,
          theme: AdaptiveTheme.material(
            Brightness.light,
            dinamico: chiaro.data,
          ),
          darkTheme: AdaptiveTheme.material(
            Brightness.dark,
            dinamico: scuro.data,
          ),
          home: home,
        ),
      ),
    );
  }

  /// Palette dinamica dal wallpaper (Android 12+); null se non disponibile
  /// (Android <12, altre piattaforme, test).
  static Future<ColorScheme?> _schemaDinamico(Brightness brightness) async {
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      return palette?.toColorScheme(brightness: brightness);
    } catch (_) {
      return null;
    }
  }

  Widget _macosApp() {
    return MaterialApp(
      title: titolo,
      debugShowCheckedModeBanner: false,
      theme: AdaptiveTheme.materialMacos(Brightness.light),
      darkTheme: AdaptiveTheme.materialMacos(Brightness.dark),
      home: home,
    );
  }

  Widget _fluentApp() {
    return fluent.FluentApp(
      title: titolo,
      debugShowCheckedModeBanner: false,
      theme: AdaptiveTheme.fluentTheme(Brightness.light),
      darkTheme: AdaptiveTheme.fluentTheme(Brightness.dark),
      localizationsDelegates: const [
        fluent.FluentLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      // Ponte Material: le schermate interne (non toccate dal design
      // system) usano Theme.of, InkWell, Tooltip… che richiedono un
      // Theme e un Material ancestor.
      builder: (context, child) {
        final brightness = fluent.FluentTheme.of(context).brightness;
        return Theme(
          data: AdaptiveTheme.material(brightness),
          child: Material(
            type: MaterialType.transparency,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: home,
    );
  }
}
