# EsamiTracker — CLAUDE.md

Guida rapida per future sessioni di sviluppo. Leggi questa pagina prima di
toccare qualsiasi file.

---

## Cos'è EsamiTracker

App Flutter cross-platform (Android, macOS, Windows) per tracciare referti di
esami del sangue:

1. L'utente importa un PDF (o scansiona con la fotocamera su Android).
2. Un modello AI locale estrae i valori numerici (nome, valore, unità, range).
3. L'esame viene salvato in SQLite locale (Drift) e caricato su Google Drive
   (JSON + PDF originale) — Drive è la fonte di verità.
4. La UI mostra uno snapshot dell'ultimo valore noto per ogni parametro e
   grafici temporali interattivi.

---

## Stack tecnico — versioni fisse

| Layer | Libreria | Versione |
|-------|----------|---------|
| Stato | flutter_riverpod | 2.6.1 |
| DB locale | drift + drift_flutter | 2.21.0 / 0.2.1 |
| Drive API | googleapis + googleapis_auth | 13.2.0 / 1.6.0 |
| Charts | fl_chart | 0.69.2 |
| PDF import | pdfrx | >=2.2.24 <2.3.0 (non aggiornare a 2.3+) |
| Drag & drop | desktop_drop | 0.7.1 |
| Design macOS | liquid_glass_widgets | 0.5.x (non 0.6+) |
| Design Windows | fluent_ui | 4.15.1 |
| Theme Android | dynamic_color | 1.8.1 |

**Flutter SDK**: ^3.9.2. **Dart SDK**: ^3.9.2.

---

## Struttura directory

```
lib/
  core/               costanti.dart — tutte le costanti (nomi pref, endpoint, cartelle Drive)
  data/
    db/               database.dart + database.g.dart (Drift, schema v1)
    mock/             mock_esami.dart
  models/             Esame, ValoreEsame, RangeRiferimento, StatoValore,
                      ParametroSnapshot, SerieParametro
  providers/          providers.dart (esporta anche esami_notifier e sync_notifier)
  repositories/
    esame_repository.dart    CRUD locale + sync Drive + snapshot + serie
    drive_repository.dart    Drive API (list, download, upload JSON/PDF, CSV export)
    vision_repository.dart   LLM pipeline + parseRisposta (parser statico tolerante)
  screens/
    home_shell.dart          NavigationBar/Rail adattiva, 3 tab
    snapshot/                SnapshotScreen + ParametroCard
    grafici/                 GraficiScreen (ListView.builder lazy) + GraficoParametroCard
                             + GraficoFullscreen
    import/                  ImportScreen (desktop) + _AndroidImportScreen
                             ImportController (StateNotifier) + TabellaValoriEditor
    impostazioni/            ImpostazioniScreen + _EsportaCsvButton
    onboarding/              OnboardingScreen
  services/
    android/          android_import_service.dart (MethodChannel Dart→Kotlin)
    auth/             drive_auth_service.dart + archivio_credenziali.dart
    pdf/              pdf_rasterizzatore.dart (PdfrxRasterizzatore)
    vision/           vision_client.dart (interfaccia) + lm_studio_client.dart
                      + ollama_client.dart
  ui/platform/        adaptive_platform.dart, adaptive_theme.dart,
                      adaptive_scaffold.dart, adaptive_navigation.dart,
                      adaptive_button.dart, adaptive_card.dart
  main.dart

android/app/src/main/kotlin/.../MainActivity.kt   Kotlin native bridge
test/
  integration_end_to_end_test.dart   4 test E2E con FakeVisionClient
```

---

## Architettura

### Stato (Riverpod)

- `databaseProvider` → `AppDatabase` (Drift, singleton con onDispose)
- `esameRepositoryProvider` → `EsameRepository` (db + drive)
- `driveRepositoryProvider` → `DriveRepository`
- `visionRepositoryProvider` → `FutureProvider<VisionRepository>` (legge SharedPrefs)
- `importControllerProvider` → `StateNotifierProvider<ImportController, ImportStato>`
- `esamiNotifierProvider`, `syncNotifierProvider` → notifier per lista esami e sync
- `primoAvvioProvider` → `FutureProvider<bool>` (legge SharedPrefs)
- `usaDatiMockProvider` → `StateProvider<bool>` (true finché non arriva un esame reale)

**Regola**: mai usare `ref.read` dentro `build`. Usa `ref.watch` per valori
reattivi, `ref.read(p.notifier)` per chiamare metodi.

### Drive come fonte di verità

- `EsameRepository.syncDaDrive()` confronta `modifiedTime` su Drive con
  `modificatoIl` in SQLite per evitare download inutili.
- Ogni esame su Drive è `data/YYYY-MM-DD.json` + `pdf/YYYY-MM-DD.pdf`.
- Export CSV va in `export/esami_export_YYYY-MM-DD.csv`.
- Cartella radice configurabile: `Costanti.cartellaDrive = 'Esami del Sangue'`.

### Pipeline LLM (desktop)

```
PDF → pdfrx.rasterizza() → List<Uint8List> PNG
  → VisionRepository.estraiValori(pagine)
    → LmStudioClient o OllamaClient → JSON string
    → VisionRepository.parseRisposta(json) → RisultatoEstrazione
```

- `_maxPagineInsieme = 2`: ≤2 pagine vanno tutte in una sola richiesta.
- Per referti più lunghi: una pagina per volta, poi deduplicazione per nome.
- Retry automatico a temperatura 0 se il primo tentativo non produce JSON valido.
- `parseRisposta` è `static`: usabile ovunque senza istanziare il repository.

### Pipeline Android (Gemini Nano)

```
ML Kit Document Scanner → List<Base64 JPEG>
  → ML Kit TextRecognition OCR → testo grezzo
  → Gemini Nano (AICore) prompt → JSON string
  → (Dart) VisionRepository.parseRisposta(json) → RisultatoEstrazione
```

MethodChannel: `"com.danieledituri.esami_tracker/android_import"`
Metodi: `isAiCoreSupported`, `avviaScanner`, `estraiTesto`

Fallback: se `isAiCoreSupported` → false, il banner lo segnala e l'utente
inserisce i valori manualmente dopo la scansione.

---

## Database (Drift)

Schema v1, due tabelle:

**TabellaEsami** (PK: `dataIso TEXT`)
- `dataIso TEXT` — formato `YYYY-MM-DD`
- `laboratorio TEXT?`
- `jsonDriveId TEXT?`
- `pdfDriveId TEXT?`
- `modificatoIl DATETIME?`

**TabellaValori** (PK: `id INTEGER AUTOINCREMENT`)
- `esameDataIso TEXT` → FK → TabellaEsami (CASCADE DELETE)
- `nome TEXT`
- `valore REAL`
- `unita TEXT DEFAULT ''`
- `rangeMin REAL?`
- `rangeMax REAL?`

**Attenzione**: `database.g.dart` è generato (1568 righe). Non modificarlo a
mano a meno che `build_runner` non funzioni nell'ambiente corrente. Per
aggiungere colonne a TabellaEsami servono:
1. Modifica di `database.dart` (nuova colonna + incremento `schemaVersion`)
2. Aggiunta di `MigrationStrategy.onUpgrade` con `addColumn(...)`
3. Riesecuzione di `dart run build_runner build --delete-conflicting-outputs`
4. Aggiornamento manuale di `database.g.dart` se build_runner non gira

In-memory per test: `AppDatabase.inMemory()`.

---

## UI adattiva

| Piattaforma | Design system | Tema |
|-------------|--------------|------|
| Android | Material 3 + Dynamic Color (Material You) | `ThemeMode.system` |
| macOS | Liquid Glass Widgets | `ThemeMode.system` |
| Windows | Fluent UI | `ThemeMode.system` |

`AdaptivePlatform.corrente` → enum `PiattaformaApp { android, macos, windows }`.

Tutte le transizioni usano `_FadeSlideTransitionBuilder` (Offset(0, 0.04) +
FadeTransition, curva `easeOutCubic`) in `adaptive_theme.dart`.

Grafici: `ListView.builder` lazy + `AutomaticKeepAliveClientMixin` su
`_CardGrafico` per non ricostruire i grafici già disegnati.

---

## Modelli vision locali (desktop)

Consigliati: **Qwen3-VL 8B** (MLX 4-bit su Mac; GGUF su Windows).

| Backend | Endpoint default | Formato richiesta |
|---------|-----------------|-------------------|
| LM Studio | `http://localhost:1234/v1/chat/completions` | OpenAI multimodal |
| Ollama | `http://localhost:11434/api/generate` | Ollama native, `images: []` |

Configurazione salvata in SharedPreferences (`prefTipoModello`, `prefEndpointModello`,
`prefNomeModello`). Cambiabile in ImpostazioniScreen.

---

## Android — dipendenze native

`android/app/build.gradle.kts`:
```kotlin
minSdk = 23
compileSdk = 35
dependencies {
  implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0-beta1")
  implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
  implementation("com.google.ai.edge.aicore:aicore:0.0.1-exp.1")
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
}
```

Gemini Nano via AICore: solo **Pixel 8+ con Android 14+**. `checkAvailability()`
ritorna `AvailabilityStatus.AVAILABLE` solo in quel caso.

Il `scannerLauncher` è registrato come proprietà della classe MainActivity (non
dentro `configureFlutterEngine`) per rispettare il ciclo di vita di
`ComponentActivity`.

---

## Google Drive OAuth

- Flusso loopback: il browser apre Google, il redirect torna a `localhost:PORT`.
- Client ID/Secret inseriti dall'utente in ImpostazioniScreen e salvati in
  `flutter_secure_storage` (Keychain/Keystore/DPAPI).
- Refresh token persistito: nessun re-login salvo revoca.

---

## Build

```bash
# Android (debug)
flutter build apk --debug

# Android (release)
flutter build apk --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Test
flutter test

# Rigenera database.g.dart dopo modifiche a database.dart
dart run build_runner build --delete-conflicting-outputs
```

**Nota**: il build di Drift non gira nell'ambiente cloud (nessun `flutter`
disponibile). Eseguire in locale.

---

## Funzionalità pending (da implementare)

### 1. OCR da immagini su desktop (Windows/macOS)

Attualmente desktop accetta solo PDF. Aggiungere:
- Schermata iniziale con scelta "PDF / Immagine" (`_SceltaTipoImport`)
- Per immagini: `file_picker` con filtro `[jpg, jpeg, png, webp]`
- Rasterizzazione: immagini già PNG → passarle direttamente a `VisionRepository`
  (non serve pdfrx)
- `ImportController` va esteso con `importaImmagini(List<Uint8List>)`

### 2. Commento AI sui valori (insights in linguaggio naturale)

Dopo l'estrazione riuscita, fare un'ulteriore chiamata LLM con un prompt
"da medico curioso" che commenti i valori importanti da monitorare:

```
POST stesso endpoint, modello vision (o text-only se disponibile)
Prompt: "Sei un assistente sanitario. Ecco i valori di un esame del sangue: [JSON].
Scrivi 2-3 frasi in italiano su cosa è importante monitorare. Sii preciso e
non allarmista. Rispondi SOLO con il testo, nessun markdown."
```

Memorizzazione: due opzioni
- **Opzione A** (più pulita): aggiungere colonna `commento TEXT?` a TabellaEsami
  (schema v2, migrazione con `addColumn`), aggiornare `database.g.dart`
  (manualmente se build_runner non disponibile: aggiungere campo `commento`
  a `TabellaEsamiData`, `TabellaEsamiCompanion`, getter in `$TabellaEsamiTable`)
- **Opzione B** (senza toccare il DB): salvare in SharedPreferences con chiave
  `commento_YYYY-MM-DD`

Mostrare il commento in `TabellaValoriEditor` (prima del pulsante Salva) e
nella schermata dettaglio esame se creata.

Su Android: il commento va generato con Gemini Nano dopo l'OCR, stessa
MethodChannel, nuovo metodo `generaCommento(String jsonValori)`.

---

## Convenzioni di codice

- **Lingua**: italiano per nomi variabili/metodi/commenti nel codice Dart/Kotlin.
  Inglese per nomi di file, costanti chiave e commit message.
- **Nessun commento** a meno che il "perché" non sia ovvio.
- **Nessuna gestione errori per casi impossibili** — solo ai bordi del sistema
  (input utente, API esterne).
- Provider Riverpod: file `providers/providers.dart` esporta tutto; i consumer
  importano solo quello.
- Modelli immutabili con `copyWith`.
- `VisionRepository.parseRisposta` è il punto centralizzato per il parsing JSON
  del modello: usarlo sempre, non scrivere parser alternativi.
- `Esame.dataIso` (`YYYY-MM-DD`) è la chiave naturale in tutto il sistema
  (SQLite PK, nome file Drive, SharedPreferences key).

---

## Errori noti / trappole

| Problema | Soluzione |
|----------|-----------|
| `catch (_: Exception)` in Kotlin 2.1+ | Usare `catch (e: Exception)` |
| `RisultatoEstrazione.fromJson()` non esiste | Usare `VisionRepository.parseRisposta(jsonString)` |
| Import Kotlin ML Kit sbagliati | `com.google.mlkit.vision.text.TextRecognition` (non gms.mlkit) |
| `liquid_glass_widgets` 0.6+ rompe | Fissato a `^0.5.0` in pubspec.yaml |
| `pdfrx` 2.3+ richiede Flutter >3.41 | Fissato a `>=2.2.24 <2.3.0` |
| `database.g.dart` da non toccare a mano | Solo build_runner; se non disponibile, patch manuale mirata |
| LM Studio: lista immagini vuota → crash? | No: array vuoto `images: []` è testo-only valido |
| Ollama: `"images": []` | Accettato nativamente, nessuna modifica necessaria |
