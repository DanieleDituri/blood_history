import 'package:flutter/material.dart';

import '../ui/platform/adaptive_navigation.dart';
import '../ui/platform/adaptive_platform.dart';
import '../ui/platform/macos_menu_bar.dart';
import 'grafici/grafici_screen.dart';
import 'impostazioni/impostazioni_screen.dart';
import 'import/import_screen.dart';
import 'snapshot/snapshot_screen.dart';

/// Shell dell'app: la navigazione concreta la decide [AdaptiveNavigation]
/// (NavigationBar su Android, sidebar a sinistra su macOS, NavigationView
/// su Windows).
///
/// Snapshot / Grafici / Import sono le 3 tab principali.
/// Impostazioni ha [DestinazioneAdaptive.isFooter] = true → in fondo alla
/// sidebar su macOS/Windows, come voce normale su Android.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  static const _destinazioni = [
    DestinazioneAdaptive(
      icona: Icons.dashboard_outlined,
      iconaAttiva: Icons.dashboard,
      etichetta: 'Snapshot',
    ),
    DestinazioneAdaptive(
      icona: Icons.show_chart_outlined,
      iconaAttiva: Icons.show_chart,
      etichetta: 'Grafici',
    ),
    DestinazioneAdaptive(
      icona: Icons.upload_file_outlined,
      iconaAttiva: Icons.upload_file,
      etichetta: 'Import',
    ),
    DestinazioneAdaptive(
      icona: Icons.settings_outlined,
      iconaAttiva: Icons.settings,
      etichetta: 'Impostazioni',
      isFooter: true,
    ),
  ];

  static const _schermate = [
    SnapshotScreen(),
    GraficiScreen(),
    ImportScreen(),
    ImpostazioniScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = AdaptiveNavigation(
      indiceSelezionato: _indice,
      onDestinazioneSelezionata: (i) => setState(() => _indice = i),
      destinazioni: _destinazioni,
      schermate: _schermate,
    );

    if (AdaptivePlatform.corrente == PiattaformaApp.macos) {
      return MacosMenuBar(
        onNuovoImport: () => setState(() => _indice = 2),
        onNavigaImpostazioni: () => setState(() => _indice = 3),
        child: nav,
      );
    }
    return nav;
  }
}
