import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/costanti.dart';
import '../data/db/database.dart';
import '../repositories/drive_repository.dart';
import '../repositories/esame_repository.dart';
import '../repositories/vision_repository.dart';
import '../services/auth/drive_auth_service.dart';
import '../services/pdf/pdf_rasterizzatore.dart';
import '../services/pdf/pdf_testo_estrattore.dart';
import '../services/vision/lm_studio_client.dart';
import '../services/vision/ollama_client.dart';
import '../services/vision/vision_client.dart';

// Re-esporta i notifier così i consumer importano solo questo file.
export 'esami_notifier.dart';
export 'sync_notifier.dart';

/// Mostra i dati mock nella Snapshot finché non ci sono esami veri in
/// cache (il primo import reale prende automaticamente il sopravvento).
final usaDatiMockProvider = StateProvider<bool>((ref) => true);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authServiceProvider = Provider<DriveAuthService>(
  (ref) => DriveAuthService(),
);

final driveRepositoryProvider = Provider<DriveRepository>(
  (ref) => DriveRepository(ref.watch(authServiceProvider)),
);

final esameRepositoryProvider = Provider<EsameRepository>(
  (ref) => EsameRepository(
    ref.watch(databaseProvider),
    drive: ref.watch(driveRepositoryProvider),
  ),
);

// ---- Onboarding -------------------------------------------------------------

/// true se l'utente non ha ancora completato il flusso di primo avvio.
final primoAvvioProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(Costanti.prefOnboardingCompletato) ?? false);
});

// ---- Modello vision locale --------------------------------------------------

class ConfigModello {
  final String tipo; // 'lmstudio' | 'ollama'
  final String endpoint;
  final String modello;

  const ConfigModello({
    required this.tipo,
    required this.endpoint,
    required this.modello,
  });
}

final configModelloProvider = FutureProvider<ConfigModello>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final tipo = prefs.getString(Costanti.prefTipoModello) ?? 'lmstudio';
  final ollama = tipo == 'ollama';
  return ConfigModello(
    tipo: tipo,
    endpoint:
        prefs.getString(Costanti.prefEndpointModello) ??
        (ollama ? Costanti.endpointOllama : Costanti.endpointLmStudio),
    modello:
        prefs.getString(Costanti.prefNomeModello) ??
        (ollama
            ? Costanti.modelloDefaultOllama
            : Costanti.modelloDefaultLmStudio),
  );
});

final visionRepositoryProvider = FutureProvider<VisionRepository>((ref) async {
  final config = await ref.watch(configModelloProvider.future);
  final VisionClient client = config.tipo == 'ollama'
      ? OllamaClient(endpoint: config.endpoint, modello: config.modello)
      : LmStudioClient(endpoint: config.endpoint, modello: config.modello);
  return VisionRepository(client);
});

final pdfRasterizzatoreProvider = Provider<PdfRasterizzatore>(
  (ref) => PdfrxRasterizzatore(),
);

final pdfTestoEstrattoreProvider = Provider<PdfTestoEstrattore>(
  (ref) => PdfTestoEstrattore(),
);

// ---- Android: modalità estrazione -------------------------------------------

/// 'ocr' | 'llm' | null (null = non ancora scelto)
final modalitaAndroidProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(Costanti.prefModalitaAndroid);
});

// ---- Desktop: modalità estrazione -------------------------------------------

/// 'vision' (default) | 'ocr'
final modalitaDesktopProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(Costanti.prefModalitaDesktop) ?? 'vision';
});
