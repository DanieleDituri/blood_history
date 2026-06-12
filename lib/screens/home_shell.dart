import 'package:flutter/material.dart';

import '../ui/platform/adaptive_navigation.dart';
import '../ui/platform/adaptive_scaffold.dart';
import 'snapshot/snapshot_screen.dart';

/// Shell dell'app: la navigazione concreta la decide [AdaptiveNavigation]
/// (NavigationBar su Android, GlassBottomBar su macOS, NavigationView
/// laterale su Windows).
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
    ),
  ];

  static const _schermate = [
    SnapshotScreen(),
    _InCostruzione(titolo: 'Grafici'),
    _InCostruzione(titolo: 'Import'),
    _InCostruzione(titolo: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigation(
      indiceSelezionato: _indice,
      onDestinazioneSelezionata: (i) => setState(() => _indice = i),
      destinazioni: _destinazioni,
      schermate: _schermate,
    );
  }
}

/// Placeholder per le schermate delle sessioni successive.
class _InCostruzione extends StatelessWidget {
  final String titolo;

  const _InCostruzione({required this.titolo});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      titolo: titolo,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('$titolo in arrivo nella prossima sessione'),
          ],
        ),
      ),
    );
  }
}
