import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/costanti.dart';
import '../data/db/database.dart';
import '../data/mock/mock_esami.dart';
import '../models/parametro_snapshot.dart';
import '../repositories/drive_repository.dart';
import '../repositories/esame_repository.dart';
import '../repositories/vision_repository.dart';
import '../services/auth/drive_auth_service.dart';
import '../services/pdf/pdf_rasterizzatore.dart';
import '../services/vision/lm_studio_client.dart';
import '../services/vision/ollama_client.dart';
import '../services/vision/vision_client.dart';

/// Mostra i dati mock nella Snapshot finché non ci sono esami veri in
/// cache (il primo import reale prende automaticamente il sopravvento).
final usaDatiMockProvider = StateProvider<bool>((ref) => true);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Accesso a Drive: autorizzazione una tantum, poi sempre silenzioso.
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

// ---- Modello vision locale --------------------------------------------------

/// Configurazione del backend vision, dalle Impostazioni (con default
/// LM Studio).
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

// ---- Snapshot ----------------------------------------------------------------

/// Ultimo valore noto di ogni parametro, per la griglia della Snapshot.
final snapshotProvider = FutureProvider<List<ParametroSnapshot>>((ref) async {
  final repo = ref.watch(esameRepositoryProvider);
  final reale = await repo.snapshot();

  // Dati veri in cache → si usano quelli, mock o non mock.
  if (reale.isNotEmpty || !ref.watch(usaDatiMockProvider)) return reale;

  // Nessun dato vero: stessa logica "ultimo valore per parametro" sui mock.
  final db = AppDatabase.inMemory();
  try {
    final repoMock = EsameRepository(db);
    for (final esame in MockEsami.esami) {
      await repoMock.salvaEsame(esame);
    }
    return await repoMock.snapshot();
  } finally {
    await db.close();
  }
});
