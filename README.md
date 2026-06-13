# EsamiTracker

Applicazione Flutter cross-platform (Android, macOS, Windows) per tracciare i referti degli esami del sangue nel tempo.  
Importa PDF/foto, estrae i valori con un modello vision locale (LM Studio / Ollama) o con **Gemini Nano on-device** su Android, archivia tutto su Google Drive e mostra snapshot e grafici storici.

---

## Caratteristiche principali

| Funzionalità | Android | macOS | Windows |
|---|---|---|---|
| Import referto | ML Kit Document Scanner + Gemini Nano | File picker + modello locale | File picker + modello locale |
| Estrazione AI | Gemini Nano (on-device, gratis) | LM Studio / Ollama (locale) | LM Studio / Ollama (locale) |
| Design system | Material 3 + Material You | Liquid Glass (stile macOS) | Fluent UI |
| Tema chiaro/scuro | Automatico (sistema) | Automatico (sistema) | Automatico (sistema) |
| Sync dati | Google Drive | Google Drive | Google Drive |
| Export CSV | ✅ (Drive) | ✅ (Drive) | ✅ (Drive) |

---

## Prerequisiti

### Tutti i target

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.35.x** o superiore  
  (consigliato: usa [fvm](https://fvm.app/) per gestire le versioni)
- Dart **3.9.2+** (incluso nel Flutter SDK)
- Account Google per Google Drive OAuth

### macOS

- Xcode 15+
- macOS 13 (Ventura) o superiore
- CocoaPods: `sudo gem install cocoapods`

### Windows

- Visual Studio 2022 con workload **Desktop development with C++**
- Windows 10 o superiore (SDK 10.0.17763.0+)

### Android

- Android Studio / SDK con build-tools 35
- Dispositivo o emulatore Android API **23+**
- Per Gemini Nano: **Pixel 8 / 8 Pro / 8a / 9 series** con **Android 14** (API 34)  
  Su altri dispositivi l'app funziona con inserimento manuale

---

## Setup Google Drive OAuth

1. Vai su [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nuovo progetto (o seleziona quello esistente)
3. Attiva l'**API Google Drive**:  
   _API e servizi → Libreria → cerca "Google Drive API" → Abilita_
4. Crea le credenziali OAuth 2.0:  
   _API e servizi → Credenziali → Crea credenziali → ID client OAuth_
   - **Tipo applicazione**: App desktop
   - **Nome**: EsamiTracker (o a piacere)
5. Scarica il file JSON delle credenziali
6. Copia **Client ID** e **Client Secret** — ti serviranno al primo avvio

> **Schermata di consenso OAuth**: aggiungi il tuo indirizzo email come _utente di test_ mentre l'app è in modalità "Testing" su Google Cloud. Puoi aggiungere fino a 100 utenti senza passare alla verifica.

### Come inserire le credenziali nell'app

Al primo avvio appare l'onboarding che chiede le credenziali, oppure:

1. Apri **Impostazioni**
2. Scorri fino alla sezione **Google Drive**
3. Inserisci Client ID e Client Secret
4. Clicca **Salva impostazioni**
5. Clicca **Collega Drive**: si apre il browser per autorizzare l'accesso

In alternativa puoi passarle come `--dart-define`:

```bash
flutter run -d macos \
  --dart-define=DRIVE_CLIENT_ID=xxx.apps.googleusercontent.com \
  --dart-define=DRIVE_CLIENT_SECRET=yyy
```

---

## Configurazione LM Studio / Ollama (solo macOS e Windows)

L'estrazione da PDF usa un modello vision locale. Devi avere uno dei due server attivi.

### LM Studio (consigliato su macOS, GPU Apple Silicon)

1. Scarica [LM Studio](https://lmstudio.ai/)
2. Carica il modello: cerca **qwen/qwen3-vl-8b** nella libreria  
   (su Mac con M-series usa la variante MLX 4-bit per prestazioni ottimali)
3. Avvia il server locale: _Local Server → Start_  
   Endpoint: `http://localhost:1234/v1`
4. In EsamiTracker → Impostazioni: seleziona **LM Studio**, imposta l'endpoint e il nome modello

### Ollama

```bash
# Installa Ollama (macOS/Linux)
brew install ollama

# Scarica il modello
ollama pull qwen3-vl:8b

# Avvia il server (gira su localhost:11434 di default)
ollama serve
```

In EsamiTracker → Impostazioni: seleziona **Ollama**.

---

## Prima build

```bash
# 1. Clona il repository
git clone https://github.com/danieledituri/blood_history.git
cd blood_history

# 2. Installa le dipendenze
flutter pub get

# 3. Rigenera il codice del database Drift (se necessario)
dart run build_runner build --delete-conflicting-outputs

# 4. Esegui i test
flutter test
```

---

## Build di rilascio

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
```

Per un bundle ottimizzato (Play Store):

```bash
flutter build appbundle --release
```

> **Gemini Nano**: richiede `com.google.ai.edge.aicore:aicore:0.0.1-exp.1` disponibile  
> su Google Maven. Su dispositivi non supportati l'app mostra un banner e usa  
> l'inserimento manuale. Nessun crash.

### macOS

```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/esami_tracker.app
```

Per distribuire fuori dall'App Store: disabilita Gatekeeper oppure firma con un  
Developer ID certificate (richiede Apple Developer Program).

### Windows

```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/esami_tracker.exe
```

Puoi creare un installer con [Inno Setup](https://jrsoftware.org/isinfo.php) puntando  
alla cartella `Release/`.

---

## Icona app e splash screen

Il progetto usa le icone Flutter di default. Per sostituirle:

1. Aggiungi a `dev_dependencies` in `pubspec.yaml`:
   ```yaml
   flutter_launcher_icons: ^0.14.3
   flutter_native_splash: ^2.4.5
   ```

2. Crea `assets/icon/icon.png` (1024×1024 px, sfondo trasparente per Android)

3. Aggiungi in `pubspec.yaml`:
   ```yaml
   flutter_icons:
     android: true
     ios: false
     image_path: "assets/icon/icon.png"
     min_sdk_android: 23

   flutter_native_splash:
     color: "#FFFFFF"
     color_dark: "#1E1E1E"
     android: true
     ios: false
   ```

4. Esegui:
   ```bash
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```

---

## Struttura del progetto

```
lib/
├── core/           # Costanti condivise
├── data/db/        # Schema Drift (SQLite locale)
├── models/         # Modelli dati puri (Esame, ValoreEsame, ...)
├── providers/      # Riverpod providers e notifier
├── repositories/   # Business logic (Drive, Esame, Vision)
├── screens/        # UI schermate (Snapshot, Grafici, Import, Impostazioni)
├── services/       # Servizi (auth, PDF, vision, Android native)
└── ui/platform/    # Design system adattivo (Material/Glass/Fluent)
```

### Cartelle Google Drive

```
Esami del Sangue/
├── pdf/            # Referti PDF originali (YYYY-MM-DD.pdf)
├── data/           # Dati estratti JSON (YYYY-MM-DD.json)
└── export/         # Export CSV (esami_export_YYYY-MM-DD.csv)
```

---

## Architettura dati

**Database locale** (Drift/SQLite):
- `TabellaEsami` — un record per esame (chiave: data ISO)
- `TabellaValori` — 1-N valori per esame

**Drive** — fonte di verità: la sync scarica solo i file modificati dopo l'ultima sync locale (`modifiedTime` di Drive vs timestamp locale). Gli esami vengono elaborati in pagine da 20 per evitare di caricare l'intera lista in memoria.

**Mock data** — 3 esami di esempio pre-caricati; scompaiono al primo import reale.

---

## Test

```bash
# Tutti i test
flutter test

# Con coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

Test disponibili:
- `models_test.dart` — serializzazione JSON
- `vision_repository_test.dart` — parsing output modello + retry
- `esame_repository_test.dart` — cache + sync Drive
- `drive_auth_service_test.dart` — flusso OAuth
- `grafici_screen_test.dart` — rendering grafici
- `adaptive_ui_test.dart` — piattaforme simulate

---

## Troubleshooting

| Problema | Soluzione |
|---|---|
| `flutter pub get` fallisce su `liquid_glass_widgets` | Verifica che Flutter sia alla versione 3.35.x (il pacchetto è pinned a 0.5.x) |
| Gemini Nano mostra "non disponibile" | Richiede Pixel 8+ con Android 14. Su altri dispositivi usa inserimento manuale |
| Drive OAuth fallisce con "redirect_uri_mismatch" | Usa tipo applicazione "App desktop" nelle credenziali, non "Web" |
| Build Windows fallisce con CMake error | Installa Visual Studio 2022 con workload "Desktop development with C++" |
| LM Studio non risponde | Verifica che il server locale sia avviato e che l'endpoint in Impostazioni sia corretto |
| Build Android: `minSdk` error da plugin | Il `minSdk` è impostato a 23 in `android/app/build.gradle.kts` |

---

## Licenza

Uso personale. Non per distribuzione commerciale.
