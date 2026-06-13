import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/costanti.dart';
import 'providers/providers.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'ui/platform/adaptive_platform.dart';
import 'ui/platform/adaptive_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it');
  // Inizializza pdfrx (imposta getCacheDirectory per la cache PDF).
  await pdfrxFlutterInitialize();
  if (AdaptivePlatform.corrente == PiattaformaApp.macos) {
    await LiquidGlassWidgets.initialize();
  }
  runApp(const ProviderScope(child: EsamiTrackerApp()));
}

class EsamiTrackerApp extends StatelessWidget {
  const EsamiTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveApp(titolo: Costanti.nomeApp, home: const _AppRouter());
  }
}

/// Decide se mostrare l'onboarding o la shell principale in base alla
/// prima esecuzione.
class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primoAvvio = ref.watch(primoAvvioProvider);
    return primoAvvio.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const HomeShell(),
      data: (primo) => primo ? const OnboardingScreen() : const HomeShell(),
    );
  }
}
