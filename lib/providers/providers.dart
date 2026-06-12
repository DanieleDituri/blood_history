import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/mock/mock_esami.dart';
import '../models/parametro_snapshot.dart';
import '../repositories/drive_repository.dart';
import '../repositories/esame_repository.dart';
import '../services/auth/drive_auth_service.dart';

/// Finché l'Import (Sessione 2) non esiste, la Snapshot mostra dati mock.
/// Quando diventerà false, i dati arriveranno dalla cache drift + Drive.
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

/// Ultimo valore noto di ogni parametro, per la griglia della Snapshot.
final snapshotProvider = FutureProvider<List<ParametroSnapshot>>((ref) async {
  if (ref.watch(usaDatiMockProvider)) {
    // Stessa logica "ultimo valore per parametro" del repository, ma sui mock.
    final db = AppDatabase.inMemory();
    try {
      final repo = EsameRepository(db);
      for (final esame in MockEsami.esami) {
        await repo.salvaEsame(esame);
      }
      return await repo.snapshot();
    } finally {
      await db.close();
    }
  }
  return ref.watch(esameRepositoryProvider).snapshot();
});
