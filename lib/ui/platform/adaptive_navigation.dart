import 'dart:ui' show ImageFilter;

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// Una voce di navigazione, indipendente dalla piattaforma.
///
/// [isFooter] = true → su macOS la voce appare in fondo alla sidebar
/// (separata da un divisore), come il pulsante Impostazioni in Notes.
/// Su Android viene trattata come voce normale nel NavigationBar.
class DestinazioneAdaptive {
  final IconData icona;
  final IconData iconaAttiva;
  final String etichetta;
  final bool isFooter;

  const DestinazioneAdaptive({
    required this.icona,
    required this.iconaAttiva,
    required this.etichetta,
    this.isFooter = false,
  });
}

/// Shell di navigazione adattiva.
///
/// - **Android** — [NavigationBar] Material 3 in basso.
/// - **macOS** — sidebar sinistra HIG-compliant: vibrancy, selezione accent,
///   app name header, separatore 0.5px — come Notes, Reminders, Mail.
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
    final schema = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Il gradiente copre l'intera finestra: sia la zona sidebar che il
    // contenuto. La sidebar applica un BackdropFilter blur su questo
    // sfondo → effetto vibrancy macOS.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  schema.surfaceContainerLowest,
                  schema.surfaceContainerHigh,
                ]
              : [
                  schema.surfaceContainerLowest,
                  schema.surfaceContainerHigh,
                ],
        ),
      ),
      child: Scaffold(
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

// ---- Sidebar macOS ----------------------------------------------------------

/// Sidebar HIG-compliant:
/// - Vibrancy: BackdropFilter blur + overlay semitrasparente.
/// - Header zone con nome app (allineata alla zona traffic-light, 52px).
/// - Selezione: sfondo accent-color pieno + testo/icona bianchi (macOS 13+).
/// - Footer separato da divisore: Impostazioni in fondo come in Notes.
/// - Separatore 0.5px lato destro tra sidebar e contenuto.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final principali = [
      for (var i = 0; i < destinazioni.length; i++)
        if (!destinazioni[i].isFooter) (indice: i, dest: destinazioni[i]),
    ];
    final footer = [
      for (var i = 0; i < destinazioni.length; i++)
        if (destinazioni[i].isFooter) (indice: i, dest: destinazioni[i]),
    ];

    // Colore overlay semitrasparente sopra il blur: crea l'effetto vibrancy.
    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.50)
        : Colors.white.withValues(alpha: 0.72);

    // Separatore laterale destro tra sidebar e contenuto.
    final separatoreColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.10);

    return SizedBox(
      width: 200,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: overlayColor,
              border: Border(
                right: BorderSide(color: separatoreColor, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Zona header: 52px per i traffic-light + nome app
                _SidebarHeader(isDark: isDark),
                // Voci principali
                for (final item in principali)
                  _VoceSidebar(
                    destinazione: item.dest,
                    selezionata: item.indice == indiceSelezionato,
                    isDark: isDark,
                    accentColor: schema.primary,
                    onTap: () => onSeleziona(item.indice),
                  ),
                const Spacer(),
                // Footer (Impostazioni)
                if (footer.isNotEmpty) ...[
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: separatoreColor,
                    indent: 12,
                    endIndent: 12,
                  ),
                  for (final item in footer)
                    _VoceSidebar(
                      destinazione: item.dest,
                      selezionata: item.indice == indiceSelezionato,
                      isDark: isDark,
                      accentColor: schema.primary,
                      onTap: () => onSeleziona(item.indice),
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header della sidebar: zona 52px per i traffic-light con nome app.
/// Su macOS, Note e Promemoria mostrano il nome dell'app in quest'area.
class _SidebarHeader extends StatelessWidget {
  final bool isDark;

  const _SidebarHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 10),
          child: Text(
            'EsamiTracker',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

/// Voce sidebar con:
/// - Selezione: sfondo accent pieno, testo e icona bianchi (macOS 13+/14+/15+).
/// - Hover: overlay semitrasparente, nessun sfondo quando inattiva.
/// - Dimensioni HIG: 30px altezza riga, icona 16px, testo 13pt semibold.
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
    // macOS 13+ (Ventura, Sonoma, Sequoia, Tahoe):
    // selezione = sfondo accent pieno, testo/icona bianchi.
    final Color bgSelezionato = widget.accentColor;
    final Color bgHover = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    final Color iconColor;
    final Color textColor;
    if (widget.selezionata) {
      iconColor = Colors.white;
      textColor = Colors.white;
    } else {
      final inactive = widget.isDark
          ? const Color(0xFFB0B0B5)
          : const Color(0xFF6E6E73);
      iconColor = inactive;
      textColor = inactive;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
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
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.destinazione.etichetta,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.selezionata
                          ? FontWeight.w600
                          : FontWeight.w400,
                      letterSpacing: -0.1,
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
