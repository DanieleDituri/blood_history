import 'package:flutter_riverpod/flutter_riverpod.dart';

// esami_notifier.dart è importato direttamente (non via providers.dart)
// per evitare import circolare: esami_notifier.dart → providers.dart.
import 'esami_notifier.dart';
import 'providers.dart' show esameRepositoryProvider;

enum StatoSync { inattivo, sincronizzando }

class StatoSincronizzazione {
  final StatoSync stato;
  final String? errore;
  final DateTime? ultimaSync;

  const StatoSincronizzazione({
    this.stato = StatoSync.inattivo,
    this.errore,
    this.ultimaSync,
  });

  bool get inCorso => stato == StatoSync.sincronizzando;
}

/// Gestisce la sincronizzazione da Drive e la espone alla UI.
///
/// La sync automatica avviene all'avvio se Drive è connesso; gli errori
/// di connessione (Drive non configurato) sono silenziati.
class SyncNotifier extends Notifier<StatoSincronizzazione> {
  @override
  StatoSincronizzazione build() {
    // Sync asincrona all'avvio: non blocca il primo render.
    Future.microtask(sincronizza);
    return const StatoSincronizzazione();
  }

  Future<void> sincronizza() async {
    state = const StatoSincronizzazione(stato: StatoSync.sincronizzando);
    try {
      final repo = ref.read(esameRepositoryProvider);
      await repo.syncDaDrive();
      await ref.read(esamiNotifierProvider.notifier).ricarica();
      state = StatoSincronizzazione(ultimaSync: DateTime.now());
    } on StateError {
      // Drive non configurato: sync silenziosa.
      state = const StatoSincronizzazione();
    } catch (e) {
      state = StatoSincronizzazione(errore: e.toString());
    }
  }
}

final syncNotifierProvider =
    NotifierProvider<SyncNotifier, StatoSincronizzazione>(SyncNotifier.new);
