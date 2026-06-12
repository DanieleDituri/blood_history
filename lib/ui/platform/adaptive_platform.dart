import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Le piattaforme con un design system dedicato.
enum PiattaformaApp {
  /// Material 3 + dynamic color (Material You).
  android,

  /// Material come base, superfici e navigazione liquid glass.
  macos,

  /// Fluent Design (FluentApp, NavigationView, Acrylic).
  windows,
}

/// Risolve la piattaforma corrente per il design system adattivo.
///
/// Tutti i widget `Adaptive*` passano da qui invece che da `Platform.isX`,
/// così i test possono forzare una piattaforma con [debugOverride].
class AdaptivePlatform {
  AdaptivePlatform._();

  /// Solo per i test: forza la piattaforma restituita da [corrente].
  @visibleForTesting
  static PiattaformaApp? debugOverride;

  static PiattaformaApp get corrente {
    if (debugOverride != null) return debugOverride!;
    if (Platform.isWindows) return PiattaformaApp.windows;
    if (Platform.isMacOS) return PiattaformaApp.macos;
    // Android, più fallback per le piattaforme non ancora supportate.
    return PiattaformaApp.android;
  }
}
