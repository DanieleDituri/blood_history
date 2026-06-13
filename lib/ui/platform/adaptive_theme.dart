import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// Temi per piattaforma del design system adattivo.
class AdaptiveTheme {
  AdaptiveTheme._();

  /// Seed usato quando i colori dinamici non sono disponibili.
  static const seedColor = Color(0xFFB71C1C);

  /// Animazioni di transizione: fade + slide leggero su tutti i target.
  static const _transizioni = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _FadeSlideTransitionBuilder(),
      TargetPlatform.macOS: _FadeSlideTransitionBuilder(),
      TargetPlatform.windows: _FadeSlideTransitionBuilder(),
      TargetPlatform.linux: _FadeSlideTransitionBuilder(),
    },
  );

  /// Tema Material (Android). Su Android [dinamico] arriva dal
  /// wallpaper (Material You); altrove o in fallback si usa il seed.
  static ThemeData material(Brightness brightness, {ColorScheme? dinamico}) {
    final schema =
        dinamico ??
        ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
    return ThemeData(
      colorScheme: schema,
      useMaterial3: true,
      pageTransitionsTheme: _transizioni,
    );
  }

  /// Blu di sistema Apple, fallback quando l'accent color dell'utente
  /// non è leggibile.
  static const bluApple = Color(0xFF007AFF);

  // ---- Tipografia macOS (SF Pro sizing) -----------------------------------
  // Dimensioni e spacing SF Pro — colori ereditati da Material automaticamente.
  // SF Pro caratteristiche: spacing negativo sui titoli, 0 sul body.
  static const _testMacos = TextTheme(
    displayLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6),
    displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
    displaySmall:  TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4),
    headlineLarge:  TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
    headlineMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
    headlineSmall:  TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleLarge:  TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.1),
    titleSmall:  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: -0.1),
    bodyLarge:   TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing:  0.0),
    bodyMedium:  TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing:  0.0),
    bodySmall:   TextStyle(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing:  0.06),
    labelLarge:  TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing:  0.0),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing:  0.04),
    labelSmall:  TextStyle(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing:  0.06),
  );

  /// Variante macOS: grigi neutri come le app native, accent color di sistema,
  /// sfondo trasparente per il liquid glass, tipografia SF Pro.
  static ThemeData materialMacos(Brightness brightness, {Color? accent}) {
    final scuro = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: accent ?? bluApple,
      brightness: brightness,
    );
    // Material 3 tinge le superfici col primario: le sostituiamo con
    // grigi neutri tipici delle finestre macOS.
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

    return ThemeData(
      colorScheme: schema,
      useMaterial3: true,
      textTheme: _testMacos,
      pageTransitionsTheme: _transizioni,
      // Input compatti stile macOS (6px raggio, padding ridotto)
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(
            color: scuro
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.18),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(
            color: scuro
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.18),
            width: 0.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      // Card arrotondate come finestre macOS (10px)
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        margin: EdgeInsets.zero,
      ),
      // Scrollbar overlay stile macOS: appare solo on-hover, si nasconde
      // a riposo — come le scrollbar native di Finder, Note, ecc.
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(false),
        trackVisibility: WidgetStateProperty.all(false),
        radius: const Radius.circular(10),
        thickness: WidgetStateProperty.all(6),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return scuro
                ? Colors.white.withValues(alpha: 0.40)
                : Colors.black.withValues(alpha: 0.30);
          }
          return Colors.transparent;
        }),
      ),
    ).copyWith(
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

/// Transizione personalizzata: fade + leggero slide verso l'alto
/// (simile all'animazione di Material You su Android 12).
class _FadeSlideTransitionBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnim = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.0, 0.04),
      end: Offset.zero,
    ).animate(curvedAnim);

    return FadeTransition(
      opacity: curvedAnim,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// Radice dell'app: sceglie l'`*App` giusta per la piattaforma.
///
/// - **Android** — [MaterialApp] con dynamic color (Material You).
/// - **macOS** — [MaterialApp] con tema HIG-compliant e liquid glass.
/// - **Windows** — [fluent.FluentApp] con bridge Material.
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
          themeMode: ThemeMode.system,
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

  /// Palette dinamica dal wallpaper (Android 12+); null se non disponibile.
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
        themeMode: ThemeMode.system,
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

  /// Accent color scelto dall'utente in Impostazioni di Sistema (macOS).
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
