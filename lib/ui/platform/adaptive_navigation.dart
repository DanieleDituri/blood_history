import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

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
/// - **macOS** — [GlassBottomBar] liquid glass sovrapposta al contenuto.
/// - **Windows** — [fluent.NavigationView] con pane laterale (non bottom bar).
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Il contenuto arriva fino in fondo: la barra glass ci galleggia
          // sopra e ne sfrutta il blur.
          Positioned.fill(child: schermate[indiceSelezionato]),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassBottomBar(
                selectedIndex: indiceSelezionato,
                onTabSelected: onDestinazioneSelezionata,
                selectedIconColor: schema.primary,
                unselectedIconColor: schema.onSurfaceVariant,
                textStyle: TextStyle(color: schema.onSurface, fontSize: 11),
                tabs: [
                  for (final d in destinazioni)
                    GlassBottomBarTab(
                      icon: Icon(d.icona),
                      activeIcon: Icon(d.iconaAttiva),
                      label: d.etichetta,
                      glowColor: schema.primary,
                    ),
                ],
              ),
            ),
          ),
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
