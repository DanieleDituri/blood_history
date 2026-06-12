import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// Una voce di navigazione, indipendente dalla piattaforma.
class DestinazioneAdaptive {
  final IconData icona;
  final IconData iconaAttiva;
  final String etichetta;

  const DestinazioneAdaptive({
    required this.icona,
    required this.iconaAttiva,
    required this.etichetta,
  });
}

/// Shell di navigazione adattiva: ogni piattaforma usa il proprio pattern.
///
/// - **Android** — [NavigationBar] Material 3 in basso.
/// - **macOS** — sidebar a sinistra con [NavigationRail], come le app
///   native macOS (Note, Promemoria, Mail, Impostazioni di Sistema).
/// - **Windows** — [fluent.NavigationView] con pane laterale Fluent.
class AdaptiveNavigation extends StatelessWidget {
  final int indiceSelezionato;
  final ValueChanged<int> onDestinazioneSelezionata;
  final List<DestinazioneAdaptive> destinazioni;

  /// Una schermata per destinazione, stesso ordine di [destinazioni].
  final List<Widget> schermate;

  const AdaptiveNavigation({
    super.key,
    required this.indiceSelezionato,
    required this.onDestinazioneSelezionata,
    required this.destinazioni,
    required this.schermate,
  }) : assert(
         destinazioni.length == schermate.length,
         'Una schermata per ogni destinazione',
       );

  @override
  Widget build(BuildContext context) {
    return switch (AdaptivePlatform.corrente) {
      PiattaformaApp.android => _android(),
      PiattaformaApp.macos => _macos(context),
      PiattaformaApp.windows => _windows(),
    };
  }

  Widget _android() {
    return Scaffold(
      body: schermate[indiceSelezionato],
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceSelezionato,
        onDestinationSelected: onDestinazioneSelezionata,
        destinations: [
          for (final d in destinazioni)
            NavigationDestination(
              icon: Icon(d.icona),
              selectedIcon: Icon(d.iconaAttiva),
              label: d.etichetta,
            ),
        ],
      ),
    );
  }

  Widget _macos(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          _SidebarMacos(
            indiceSelezionato: indiceSelezionato,
            onSeleziona: onDestinazioneSelezionata,
            destinazioni: destinazioni,
          ),
          Expanded(child: schermate[indiceSelezionato]),
        ],
      ),
    );
  }

  Widget _windows() {
    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: indiceSelezionato,
        onChanged: onDestinazioneSelezionata,
        displayMode: fluent.PaneDisplayMode.auto,
        items: [
          for (var i = 0; i < destinazioni.length; i++)
            fluent.PaneItem(
              icon: Icon(
                indiceSelezionato == i
                    ? destinazioni[i].iconaAttiva
                    : destinazioni[i].icona,
              ),
              title: Text(destinazioni[i].etichetta),
              body: schermate[i],
            ),
        ],
      ),
    );
  }
}

/// Sidebar macOS nativa: colonna con voci icona+testo, selezione con
/// rounded rect tenue, nessun indicatore Material.  Stessa struttura di
/// Note, Promemoria, Fork, ecc.
class _SidebarMacos extends StatelessWidget {
  final int indiceSelezionato;
  final ValueChanged<int> onSeleziona;
  final List<DestinazioneAdaptive> destinazioni;

  const _SidebarMacos({
    required this.indiceSelezionato,
    required this.onSeleziona,
    required this.destinazioni,
  });

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Sfondo panel sidebar — leggermente più scuro/chiaro del contenuto
    final bgColor = isDark
        ? const Color(0xFF1A1A1C)
        : const Color(0xFFECECEE);

    return Container(
      width: 180,
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spazio per la traffic-light bar di macOS
          const SizedBox(height: 52),
          for (var i = 0; i < destinazioni.length; i++)
            _VoceSidebar(
              destinazione: destinazioni[i],
              selezionata: i == indiceSelezionato,
              isDark: isDark,
              accentColor: schema.primary,
              onTap: () => onSeleziona(i),
            ),
        ],
      ),
    );
  }
}

class _VoceSidebar extends StatefulWidget {
  final DestinazioneAdaptive destinazione;
  final bool selezionata;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  const _VoceSidebar({
    required this.destinazione,
    required this.selezionata,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_VoceSidebar> createState() => _VoceSidebarState();
}

class _VoceSidebarState extends State<_VoceSidebar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bgSelezionato = widget.isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final Color bgHover = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final Color iconColor = widget.selezionata
        ? widget.accentColor
        : (widget.isDark
            ? const Color(0xFFB0B0B5)
            : const Color(0xFF6E6E73));
    final Color textColor = widget.selezionata
        ? (widget.isDark ? Colors.white : const Color(0xFF1D1D1F))
        : (widget.isDark
            ? const Color(0xFFB0B0B5)
            : const Color(0xFF6E6E73));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: widget.selezionata
                  ? bgSelezionato
                  : (_hovered ? bgHover : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Icon(
                  widget.selezionata
                      ? widget.destinazione.iconaAttiva
                      : widget.destinazione.icona,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.destinazione.etichetta,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.selezionata
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
