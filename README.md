# EsamiTracker

App Flutter cross-platform (Windows, macOS, Android) per tracciare i referti
degli esami del sangue: import PDF con estrazione valori tramite modello
vision locale, archiviazione su Google Drive, snapshot e grafici storici.

## Stato del progetto

| Sessione | Contenuto | Stato |
| --- | --- | --- |
| 1 | Scaffold, modelli, Google Drive auth, repository, cache drift, schermata Snapshot (mock) | ✅ |
| 2+ | Import PDF (LM Studio/Ollama su desktop, ML Kit + Gemini Nano su Android), Grafici, Impostazioni | ⏳ |

## Architettura

```
lib/
├── main.dart                  # bootstrap: locale it + ProviderScope + tema
├── core/costanti.dart         # nomi cartelle Drive, chiavi prefs, endpoint default
├── models/                    # modelli puri, JSON-serializzabili
│   ├── esame.dart             #   referto: data + lista valori (chiave: YYYY-MM-DD)
│   ├── valore_esame.dart      #   parametro: nome, valore, unità, range
│   ├── range_riferimento.dart #   range del referto + logica stato (±10% borderline)
│   ├── stato_valore.dart      #   enum verde/giallo/rosso + colori
│   └── parametro_snapshot.dart#   ultimo valore di un parametro, per la griglia
├── services/auth/
│   ├── drive_auth_service.dart # accesso a Drive senza login ricorrente
│   │                           # (consenso una tantum + refresh token)
│   └── archivio_credenziali.dart # keystore di piattaforma (secure storage)
├── repositories/
│   ├── drive_repository.dart  # Esami del Sangue/{pdf,data}/ su Drive
│   └── esame_repository.dart  # cache drift + sync da Drive (Drive = fonte di verità)
├── data/
│   ├── db/database.dart       # schema drift (esami 1-N valori) + query
│   └── mock/mock_esami.dart   # 3 referti finti, 15 parametri
├── providers/providers.dart   # wiring Riverpod (usaDatiMockProvider attivo)
├── ui/platform/               # design system adattivo per piattaforma
│   ├── adaptive_platform.dart #   resolver piattaforma (override nei test)
│   ├── adaptive_theme.dart    #   temi + AdaptiveApp (MaterialApp/FluentApp)
│   ├── adaptive_scaffold.dart #   AppBar / glass / ScaffoldPage
│   ├── adaptive_card.dart     #   Card / GlassContainer / Acrylic
│   ├── adaptive_navigation.dart # NavigationBar / GlassBottomBar / NavigationView
│   └── adaptive_button.dart   #   FilledButton / pillola glass / fluent.Button
└── screens/
    ├── home_shell.dart        # shell: destinazioni + AdaptiveNavigation
    └── snapshot/              # griglia card responsive con stato colorato
```

### Design system adattivo

I layout interni delle schermate sono Material e identici ovunque; solo lo
shell (scaffold, navigazione, superfici card, bottoni) cambia per piattaforma
tramite i widget `Adaptive*` di `lib/ui/platform/`:

| | Android | macOS | Windows |
| --- | --- | --- | --- |
| App | `MaterialApp` + dynamic color (Material You, fallback seed) | `MaterialApp` base | `FluentApp` (con ponte Theme/Material per i widget interni) |
| Scaffold | `Scaffold` + `AppBar` M3 | Scaffold trasparente su gradiente (sfondo per il blur) | `ScaffoldPage` + `PageHeader` |
| Card | `Card` + `InkWell` | `GlassContainer` (liquid glass) | `Acrylic` |
| Navigazione | `NavigationBar` in basso | `GlassBottomBar` flottante | `NavigationView` laterale |
| Bottoni | `FilledButton`/`IconButton` | pillola glass / `GlassIconButton` | `fluent.FilledButton`/`fluent.IconButton` |

La piattaforma è risolta da `AdaptivePlatform.corrente`; nei test si forza
con `AdaptivePlatform.debugOverride` (vedi `test/adaptive_ui_test.dart`).

⚠️ `liquid_glass_widgets` è bloccato a **0.5.x**: dalla 0.6.0 richiede
`meta ^1.17`, in conflitto con il pin di `flutter_test` su Flutter 3.35.
Da rivalutare al prossimo upgrade di Flutter.

### Formato JSON su Drive (`Esami del Sangue/data/YYYY-MM-DD.json`)

```json
{
  "data": "2026-05-12",
  "laboratorio": "Laboratorio Analisi S. Chiara",
  "valori": [
    {"nome": "Glicemia", "valore": 101, "unita": "mg/dL", "range_min": 70, "range_max": 99}
  ]
}
```

Il PDF originale è salvato come `Esami del Sangue/pdf/YYYY-MM-DD.pdf`.
La data del prelievo è la chiave naturale: un re-upload con la stessa data
sovrascrive il file esistente.

### Logica colori Snapshot

- 🟢 **In range** — valore dentro `[min, max]`
- 🟡 **Borderline** — fuori range ma entro il 10% dell'ampiezza del range
  (o del limite, per range aperti tipo `< 200`)
- 🔴 **Fuori range** — oltre la tolleranza del 10%
- ⚪ **N/D** — il referto non riportava un range

## Setup

```sh
flutter pub get
dart run build_runner build   # rigenera lib/data/db/database.g.dart dopo modifiche allo schema
flutter test
flutter run -d macos          # oppure -d windows / dispositivo Android
```

Il progetto è bloccato su Flutter 3.35.x via [fvm](https://fvm.app).

### Google Drive — senza login

Non c'è Google Sign-In: l'app è personale. Si autorizza l'accesso **una
sola volta per dispositivo** (si apre il browser, si clicca "Consenti");
da lì in poi il refresh token salvato rinnova l'accesso in silenzio, su
tutte le piattaforme (macOS, Windows e Android usano lo stesso flusso
loopback). Lo scope è `drive.file`: l'app vede solo i file che crea.

Setup una tantum in [Google Cloud Console](https://console.cloud.google.com):

1. Crea un progetto e abilita la **Google Drive API**.
2. Schermata consenso OAuth: tipo **External**, poi **pubblica l'app in
   produzione** — se resta in "Testing" Google fa scadere il refresh token
   dopo 7 giorni (per lo scope `drive.file` non serve alcuna verifica).
3. Crea un **OAuth Client ID di tipo Desktop** e copia id e secret.
4. Compila l'app con le tue credenziali:

   ```sh
   flutter run -d macos \
     --dart-define=DRIVE_CLIENT_ID=xxx.apps.googleusercontent.com \
     --dart-define=DRIVE_CLIENT_SECRET=yyy
   ```

   (in alternativa si potranno inserire nella schermata Impostazioni).

Le credenziali (refresh token incluso) sono salvate nel keystore della
piattaforma via `flutter_secure_storage`: Keychain su macOS, Keystore su
Android (minSdk 23), DPAPI su Windows. Mai in chiaro su disco — pronto
anche per un'eventuale versione pubblica. Su macOS si usa il keychain
classico (`usesDataProtectionKeychain: false`) perché quello "data
protection" richiede la firma con certificato Apple Developer; per la
versione pubblica firmata si potrà riattivare. Le credenziali salvate
dalle primissime build in `shared_preferences` vengono migrate
automaticamente al primo avvio.

Per una futura versione pubblica restano da fare (non bloccanti ora):
verifica del brand OAuth da parte di Google se gli utenti superano le
soglie, e una schermata di onboarding per il collegamento a Drive.

## Note per le sessioni successive

- La Snapshot legge da `usaDatiMockProvider` (default `true`): quando
  l'Import sarà attivo basta metterlo a `false` per passare alla cache
  drift + Drive.
- `fl_chart`, `file_picker` e `http` sono già in pubspec per la Sessione 2.
- `EsameRepository.syncDaDrive()` confronta il `modifiedTime` remoto con
  quello in cache: scarica solo i JSON nuovi o cambiati.
