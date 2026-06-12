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

  /// Blu di sistema Apple, fallback quando l'accent color dell'utente
  /// non è leggibile.
  static const bluApple = Color(0xFF007AFF);

  /// Variante macOS: niente tinta Material sulle superfici — grigi
  /// neutri come le app native — e [accent] (l'accent color di sistema
  /// dell'utente) come primario. Sfondo trasparente per il liquid glass.
  static ThemeData materialMacos(Brightness brightness, {Color? accent}) {
    final scuro = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: accent ?? bluApple,
      brightness: brightness,
    );
    // Material 3 tinge le superfici col primario: qui le sostituiamo
    // con i grigi neutri tipici delle finestre macOS.
    final schema = scuro
        ? base.copyWith(
            surface: const Color(0xFF1E1E1E),
            surfaceContainerLowest: const Color(0xFF141414),
            surfaceContainerLow: const Color(0xFF1B1B1D),
            surfaceContainer: const Color(0xFF232325),
            surfaceContainerHigh: const Color(0xFF2A2A2C),
            surfaceContainerHighest: const Color(0xFF323234),
            onSurface: const Color(0xFFF5F5F7),
            onSurfaceVariant: const Color(0xFFB0B0B5),
          )
        : base.copyWith(
            surface: const Color(0xFFF5F5F7),
            surfaceContainerLowest: const Color(0xFFFFFFFF),
            surfaceContainerLow: const Color(0xFFF7F7F8),
            surfaceContainer: const Color(0xFFF2F2F3),
            surfaceContainerHigh: const Color(0xFFECECEE),
            surfaceContainerHighest: const Color(0xFFE5E5E7),
            onSurface: const Color(0xFF1D1D1F),
            onSurfaceVariant: const Color(0xFF6E6E73),
          );
    return ThemeData(colorScheme: schema, useMaterial3: true).copyWith(
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
    return FutureBuilder<Color?>(
      future: _accentDiSistema(),
      builder: (context, accent) => MaterialApp(
        title: titolo,
        debugShowCheckedModeBanner: false,
        theme: AdaptiveTheme.materialMacos(
          Brightness.light,
          accent: accent.data,
        ),
        darkTheme: AdaptiveTheme.materialMacos(
          Brightness.dark,
          accent: accent.data,
        ),
        home: home,
      ),
    );
  }

  /// Accent color scelto dall'utente in Impostazioni di Sistema (macOS);
  /// null se non disponibile (test, versioni vecchie) → blu Apple.
  static Future<Color?> _accentDiSistema() async {
    try {
      return await DynamicColorPlugin.getAccentColor();
    } catch (_) {
      return null;
    }
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
