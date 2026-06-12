import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'adaptive_platform.dart';

/// Contenitore-card adattivo. Il contenuto ([child]) è il layout interno
/// della schermata e passa invariato; cambia solo la superficie.
///
/// - **Android** — [Card] Material 3 con [InkWell] per il tap.
/// - **macOS** — [GlassContainer] liquid glass.
/// - **Windows** — [fluent.Acrylic] con angoli arrotondati.
class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AdaptiveCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return switch (AdaptivePlatform.corrente) {
      PiattaformaApp.android => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
      PiattaformaApp.macos => GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          useOwnLayer: true,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
      PiattaformaApp.windows => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: onTap,
          child: fluent.Acrylic(child: child),
        ),
      ),
    };
  }
}
