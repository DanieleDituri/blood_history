import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'adaptive_platform.dart';

/// Bottone con etichetta (azione primaria) adattivo.
///
/// - **Android** — [FilledButton] Material 3.
/// - **macOS** — pillola [GlassContainer] liquid glass (allineata a macOS 26
///   Tahoe che usa superfici glass come linguaggio di design nativo).
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
/// - **macOS** — bottone borderless con hover/press rounded-rect: è il pattern
///   nativo macOS per i pulsanti di toolbar (Finder, Mail, Safari toolbar).
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
      PiattaformaApp.macos => _MacosIconButton(
        icona: icona,
        tooltip: tooltip,
        onPressed: onPressed,
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

// ---- macOS icon button (toolbar style) -------------------------------------

/// Bottone icona macOS nativo: borderless, 28×28px, con hover e press state
/// che mostrano un rounded rect semitrasparente (identico ai toolbar button
/// di Finder, Mail, Musica, ecc.).
class _MacosIconButton extends StatefulWidget {
  final IconData icona;
  final String? tooltip;
  final VoidCallback? onPressed;

  const _MacosIconButton({
    required this.icona,
    this.tooltip,
    this.onPressed,
  });

  @override
  State<_MacosIconButton> createState() => _MacosIconButtonState();
}

class _MacosIconButtonState extends State<_MacosIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final abilitato = widget.onPressed != null;

    Color bgColor;
    if (_pressed && abilitato) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.black.withValues(alpha: 0.13);
    } else if (_hovered && abilitato) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.09)
          : Colors.black.withValues(alpha: 0.07);
    } else {
      bgColor = Colors.transparent;
    }

    Widget btn = MouseRegion(
      cursor: abilitato ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: bgColor,
          ),
          child: Icon(
            widget.icona,
            size: 16,
            color: abilitato
                ? schema.onSurface
                : schema.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      btn = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 600),
        child: btn,
      );
    }
    return btn;
  }
}

// ---- macOS primary button (glass pill) -------------------------------------

/// Pillola glass con icona + etichetta.
/// Usa GlassContainer di liquid_glass_widgets, che implementa il linguaggio
/// di design liquid glass di macOS 26 Tahoe.
class _GlassButtonPillola extends StatefulWidget {
  final String etichetta;
  final IconData? icona;
  final VoidCallback? onPressed;

  const _GlassButtonPillola({
    required this.etichetta,
    this.icona,
    this.onPressed,
  });

  @override
  State<_GlassButtonPillola> createState() => _GlassButtonPillolaState();
}

class _GlassButtonPillolaState extends State<_GlassButtonPillola> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final abilitato = widget.onPressed != null;

    return MouseRegion(
      cursor: abilitato ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Opacity(
        opacity: abilitato ? 1.0 : 0.45,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _hovered && abilitato ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: GlassContainer(
              useOwnLayer: true,
              shape: const LiquidRoundedSuperellipse(borderRadius: 24),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icona != null) ...[
                    Icon(widget.icona, size: 16, color: schema.primary),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    widget.etichetta,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: schema.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
