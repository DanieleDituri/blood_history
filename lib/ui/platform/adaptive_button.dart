import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'adaptive_platform.dart';

/// Bottone con etichetta (azione primaria) adattivo.
///
/// - **Android** — [FilledButton] Material 3.
/// - **macOS** — pillola [GlassContainer] liquid glass.
/// - **Windows** — [fluent.FilledButton].
class AdaptiveButton extends StatelessWidget {
  final String etichetta;
  final IconData? icona;
  final VoidCallback? onPressed;

  const AdaptiveButton({
    super.key,
    required this.etichetta,
    this.icona,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return switch (AdaptivePlatform.corrente) {
      PiattaformaApp.android =>
        icona != null
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icona),
                label: Text(etichetta),
              )
            : FilledButton(onPressed: onPressed, child: Text(etichetta)),
      PiattaformaApp.macos => _GlassButtonPillola(
        etichetta: etichetta,
        icona: icona,
        onPressed: onPressed,
      ),
      PiattaformaApp.windows => fluent.FilledButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icona != null) ...[
              Icon(icona, size: 16),
              const SizedBox(width: 8),
            ],
            Text(etichetta),
          ],
        ),
      ),
    };
  }
}

/// Bottone a sola icona (azioni di toolbar) adattivo.
///
/// - **Android** — [IconButton] Material.
/// - **macOS** — [GlassIconButton] liquid glass.
/// - **Windows** — [fluent.IconButton].
class AdaptiveIconButton extends StatelessWidget {
  final IconData icona;
  final String? tooltip;
  final VoidCallback? onPressed;

  const AdaptiveIconButton({
    super.key,
    required this.icona,
    this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return switch (AdaptivePlatform.corrente) {
      PiattaformaApp.android => IconButton(
        tooltip: tooltip,
        icon: Icon(icona),
        onPressed: onPressed,
      ),
      PiattaformaApp.macos => GlassIconButton(
        icon: Icon(icona, color: Theme.of(context).colorScheme.onSurface),
        onPressed: onPressed ?? () {},
        size: 36,
      ),
      PiattaformaApp.windows => fluent.Tooltip(
        message: tooltip ?? '',
        child: fluent.IconButton(
          icon: Icon(icona, size: 18),
          onPressed: onPressed,
        ),
      ),
    };
  }
}

/// Pillola glass con icona + etichetta: liquid_glass_widgets non ha un
/// bottone con label esteso, quindi lo componiamo da [GlassContainer].
class _GlassButtonPillola extends StatelessWidget {
  final String etichetta;
  final IconData? icona;
  final VoidCallback? onPressed;

  const _GlassButtonPillola({
    required this.etichetta,
    this.icona,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final abilitato = onPressed != null;
    return Opacity(
      opacity: abilitato ? 1 : 0.5,
      child: GestureDetector(
        onTap: onPressed,
        child: GlassContainer(
          useOwnLayer: true,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icona != null) ...[
                Icon(icona, size: 18, color: schema.primary),
                const SizedBox(width: 8),
              ],
              Text(
                etichetta,
                style: TextStyle(
                  color: schema.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
