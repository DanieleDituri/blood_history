import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'core/costanti.dart';
import 'screens/home_shell.dart';
import 'ui/platform/adaptive_platform.dart';
import 'ui/platform/adaptive_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it');
  if (AdaptivePlatform.corrente == PiattaformaApp.macos) {
    // Precache degli shader liquid glass: evita glitch al primo render.
    await LiquidGlassWidgets.initialize();
  }
  runApp(const ProviderScope(child: EsamiTrackerApp()));
}

class EsamiTrackerApp extends StatelessWidget {
  const EsamiTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdaptiveApp(titolo: Costanti.nomeApp, home: HomeShell());
  }
}
