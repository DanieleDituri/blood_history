import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/costanti.dart';
import '../../providers/providers.dart';
import '../../repositories/drive_repository.dart';
import '../../services/android/android_import_service.dart';
import '../../services/auth/drive_auth_service.dart';
import '../../ui/platform/adaptive_scaffold.dart';

class ImpostazioniScreen extends ConsumerStatefulWidget {
  const ImpostazioniScreen({super.key});

  @override
  ConsumerState<ImpostazioniScreen> createState() => _ImpostazioniState();
}

class _ImpostazioniState extends ConsumerState<ImpostazioniScreen> {
  late TextEditingController _endpointLm;
  late TextEditingController _endpointOllama;
  late TextEditingController _modello;
  String _tipo = 'lmstudio';
  bool _caricato = false;

  @override
  void initState() {
    super.initState();
    _endpointLm = TextEditingController();
    _endpointOllama = TextEditingController();
    _modello = TextEditingController();
    _carica();
  }

  Future<void> _carica() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tipo = prefs.getString(Costanti.prefTipoModello) ?? 'lmstudio';
      _endpointLm.text =
          prefs.getString(Costanti.prefEndpointModello) ??
          Costanti.endpointLmStudio;
      _endpointOllama.text = Costanti.endpointOllama;
      _modello.text =
          prefs.getString(Costanti.prefNomeModello) ??
          Costanti.modelloDefaultLmStudio;
      _caricato = true;
    });
  }

  Future<void> _salva() async {
    final prefs = await SharedPreferences.getInstance();
    final endpoint =
        _tipo == 'ollama' ? _endpointOllama.text : _endpointLm.text;
    await prefs.setString(Costanti.prefTipoModello, _tipo);
    await prefs.setString(Costanti.prefEndpointModello, endpoint.trim());
    await prefs.setString(Costanti.prefNomeModello, _modello.text.trim());
    ref.invalidate(configModelloProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Impostazioni salvate')));
    }
  }

  @override
  void dispose() {
    _endpointLm.dispose();
    _endpointOllama.dispose();
    _modello.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_caricato) {
      return const AdaptiveScaffold(
        titolo: 'Impostazioni',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AdaptiveScaffold(
      titolo: 'Impostazioni',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (Platform.isAndroid) ...[
            _sezione('Estrazione su Android'),
            const _SezioneAndroidLlm(),
            const SizedBox(height: 24),
          ] else ...[
            _sezione('Modello Vision Locale'),
            _TipoModelloSelector(
              valore: _tipo,
              onCambia: (v) => setState(() => _tipo = v),
            ),
            const SizedBox(height: 16),
            const _ModalitaDesktopSelector(),
            const SizedBox(height: 16),
            _EndpointRow(
              label: 'Endpoint LM Studio',
              controller: _endpointLm,
              attivo: _tipo == 'lmstudio',
              urlTest: '${_endpointLm.text}/models',
            ),
            const SizedBox(height: 12),
            _EndpointRow(
              label: 'Endpoint Ollama',
              controller: _endpointOllama,
              attivo: _tipo == 'ollama',
              urlTest: '${_endpointOllama.text}/tags',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modello,
              decoration: const InputDecoration(
                labelText: 'Nome modello',
                hintText: 'es. qwen/qwen3-vl-8b',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salva,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva impostazioni'),
            ),
            const SizedBox(height: 24),
          ],
          _sezione('Google Drive'),
          const _DriveSection(),
          const SizedBox(height: 16),
          const _EsportaCsvButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sezione(String titolo) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      titolo,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

// ---- Sezione Android: OCR / LLM download ------------------------------------

class _SezioneAndroidLlm extends StatefulWidget {
  const _SezioneAndroidLlm();

  @override
  State<_SezioneAndroidLlm> createState() => _SezioneAndroidLlmState();
}

class _SezioneAndroidLlmState extends State<_SezioneAndroidLlm> {
  String _modalita = 'ocr';
  bool _llmDisponibile = false;
  bool _downloading = false;
  int _percentuale = 0;
  String _etichetta = '';
  StreamSubscription<ProgressoDownload>? _sub;
  final _tokenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final prefs = await SharedPreferences.getInstance();
    final llmOk = await AndroidImportService.isLlmDisponibile();
    if (mounted) {
      setState(() {
        _modalita = prefs.getString(Costanti.prefModalitaAndroid) ?? 'ocr';
        _tokenCtrl.text = prefs.getString(Costanti.prefHuggingFaceToken) ?? '';
        _llmDisponibile = llmOk;
      });
    }
  }

  Future<void> _cambiaModalita(String nuova) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Costanti.prefModalitaAndroid, nuova);
    if (mounted) setState(() => _modalita = nuova);
  }

  Future<void> _salvaToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Costanti.prefHuggingFaceToken, _tokenCtrl.text.trim());
  }

  Future<void> _avviaDownload() async {
    await _salvaToken();
    setState(() {
      _downloading = true;
      _percentuale = 0;
      _etichetta = '';
    });

    _sub = AndroidImportService.progressoDownload.listen(
      (p) {
        if (mounted) {
          setState(() {
            _percentuale = p.percentuale;
            _etichetta = p.etichetta;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _downloading = false);
      },
    );

    try {
      await AndroidImportService.scaricaModello(token: _tokenCtrl.text.trim());
      if (mounted) {
        setState(() {
          _llmDisponibile = true;
          _downloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modello Gemma 2B scaricato')),
        );
      }
    } on AndroidImportException catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore download: ${e.messaggio}')),
        );
      }
    } finally {
      await _sub?.cancel();
      _sub = null;
    }
  }

  Future<void> _cancellaModello() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Gemma 2B?'),
        content: const Text('Il modello (~1.5 GB) verrà rimosso dal dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    await AndroidImportService.cancellaModello();
    if (mounted) {
      setState(() => _llmDisponibile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modello eliminato')),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modalità corrente
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'ocr',
              icon: Icon(Icons.text_fields_outlined),
              label: Text('Solo OCR'),
            ),
            ButtonSegment(
              value: 'llm',
              icon: Icon(Icons.psychology_outlined),
              label: Text('LLM Gemma 2B'),
            ),
          ],
          selected: {_modalita},
          onSelectionChanged: (s) => _cambiaModalita(s.first),
        ),
        const SizedBox(height: 16),

        // Stato modello / download
        if (_modalita == 'llm') ...[
          if (_llmDisponibile) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline, color: Colors.green[700]),
              title: const Text('Gemma 2B installato'),
              subtitle: const Text('~1.5 GB · estrazione LLM attiva'),
              trailing: OutlinedButton.icon(
                onPressed: _cancellaModello,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Elimina'),
              ),
            ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.download_outlined, color: schema.primary),
              title: const Text('Gemma 2B non scaricato'),
              subtitle: const Text('~1.5 GB — richiede accettazione licenza su hf.co'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token HuggingFace (opzionale)',
                hintText: 'hf_xxxxxxxxxxxx',
                border: OutlineInputBorder(),
                helperText: 'Necessario se hai accettato la licenza Gemma su hf.co',
              ),
            ),
            const SizedBox(height: 12),
            if (_downloading) ...[
              LinearProgressIndicator(value: _percentuale / 100),
              const SizedBox(height: 4),
              Text(
                '$_percentuale%  $_etichetta',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              FilledButton.icon(
                onPressed: _avviaDownload,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Scarica modello (~1.5 GB)'),
              ),
          ],
        ],
      ],
    );
  }
}

// ---- Selettore modalità estrazione desktop ---------------------------------

class _ModalitaDesktopSelector extends StatefulWidget {
  const _ModalitaDesktopSelector();

  @override
  State<_ModalitaDesktopSelector> createState() =>
      _ModalitaDesktopSelectorState();
}

class _ModalitaDesktopSelectorState extends State<_ModalitaDesktopSelector> {
  String _modalita = 'vision';
  bool _caricato = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _modalita =
            prefs.getString(Costanti.prefModalitaDesktop) ?? 'vision';
        _caricato = true;
      });
    }
  }

  Future<void> _cambia(String nuova) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Costanti.prefModalitaDesktop, nuova);
    if (mounted) setState(() => _modalita = nuova);
  }

  @override
  Widget build(BuildContext context) {
    if (!_caricato) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modalità estrazione',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'vision',
              icon: Icon(Icons.image_outlined),
              label: Text('Vision'),
            ),
            ButtonSegment(
              value: 'ocr',
              icon: Icon(Icons.text_fields_outlined),
              label: Text('OCR testo'),
            ),
          ],
          selected: {_modalita},
          onSelectionChanged: (s) => _cambia(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          _modalita == 'ocr'
              ? 'OCR: estrae e analizza il testo del PDF — nessun LLM, più rapido ma meno accurato'
              : 'Vision: rasterizza il PDF e lo invia al modello multimodale — funziona anche su referti scansionati',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---- Selezione tipo modello -------------------------------------------------

class _TipoModelloSelector extends StatelessWidget {
  final String valore;
  final ValueChanged<String> onCambia;

  const _TipoModelloSelector({required this.valore, required this.onCambia});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'lmstudio', label: Text('LM Studio')),
        ButtonSegment(value: 'ollama', label: Text('Ollama')),
      ],
      selected: {valore},
      onSelectionChanged: (set) => onCambia(set.first),
    );
  }
}

// ---- Riga endpoint con bottone test ----------------------------------------

class _EndpointRow extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool attivo;
  final String urlTest;

  const _EndpointRow({
    required this.label,
    required this.controller,
    required this.attivo,
    required this.urlTest,
  });

  @override
  State<_EndpointRow> createState() => _EndpointRowState();
}

class _EndpointRowState extends State<_EndpointRow> {
  bool _testing = false;
  bool? _ok;

  Future<void> _testa() async {
    setState(() {
      _testing = true;
      _ok = null;
    });
    try {
      final resp = await http
          .get(Uri.parse(widget.urlTest))
          .timeout(const Duration(seconds: 5));
      setState(() => _ok = resp.statusCode < 400);
    } catch (_) {
      setState(() => _ok = false);
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            enabled: widget.attivo,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
              suffixIcon: _ok == null
                  ? null
                  : Icon(
                      _ok! ? Icons.check_circle : Icons.error_outline,
                      color: _ok! ? Colors.green : schema.error,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: widget.attivo && !_testing ? _testa : null,
          child: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Test'),
        ),
      ],
    );
  }
}

// ---- Sezione Drive ----------------------------------------------------------

/// Sezione Google Drive: mostra lo stato della connessione e permette di
/// collegare / disconnettere Drive. Gestisce anche l'inserimento delle
/// credenziali OAuth (Client ID e Secret) quando non sono compilate nel
/// binario con --dart-define.
class _DriveSection extends ConsumerStatefulWidget {
  const _DriveSection();

  @override
  ConsumerState<_DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends ConsumerState<_DriveSection> {
  /// null = verifica in corso; true = collegato; false = non collegato.
  bool? _collegato;
  bool _inCollegamento = false;
  String? _errore;

  final _clientIdCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inizializza();
  }

  Future<void> _inizializza() async {
    // Carica eventuali credenziali OAuth salvate nelle impostazioni.
    final prefs = await SharedPreferences.getInstance();
    _clientIdCtrl.text = prefs.getString(Costanti.prefDriveClientId) ?? '';
    _secretCtrl.text = prefs.getString(Costanti.prefDriveClientSecret) ?? '';

    // Controlla se c'è già una sessione Drive valida (refresh token presente).
    // Un'eccezione qui significa semplicemente "non collegato" — non è un errore.
    final auth = ref.read(authServiceProvider);
    bool ok;
    try {
      ok = await auth.ripristinaSessione();
    } on DriveAuthException {
      ok = false;
    } catch (_) {
      ok = false;
    }
    if (mounted) setState(() => _collegato = ok);
  }

  Future<void> _collega() async {
    setState(() {
      _inCollegamento = true;
      _errore = null;
    });
    // Salva client ID e secret prima di tentare il collegamento.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      Costanti.prefDriveClientId,
      _clientIdCtrl.text.trim(),
    );
    await prefs.setString(
      Costanti.prefDriveClientSecret,
      _secretCtrl.text.trim(),
    );

    try {
      await ref.read(authServiceProvider).collega();
      if (mounted) {
        setState(() {
          _collegato = true;
          _inCollegamento = false;
        });
        // Sincronizza subito dopo il collegamento.
        ref.read(syncNotifierProvider.notifier).sincronizza();
      }
    } on DriveAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errore = e.messaggio;
          _inCollegamento = false;
        });
      }
    }
  }

  Future<void> _disconnetti() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnetti Drive?'),
        content: const Text(
          'Le credenziali salvate verranno rimosse. '
          'Potrai ricollegarti in qualsiasi momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnetti'),
          ),
        ],
      ),
    );
    if (conferma == true) {
      await ref.read(authServiceProvider).scollega();
      if (mounted) setState(() => _collegato = false);
    }
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Verifica iniziale ancora in corso.
    if (_collegato == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_collegato == true) {
      return _ConnessaView(
        sync: ref.watch(syncNotifierProvider),
        onSync: () => ref.read(syncNotifierProvider.notifier).sincronizza(),
        onDisconnetti: _disconnetti,
      );
    }

    // Non collegato: mostra form per le credenziali OAuth + bottone.
    return _CollegaView(
      clientIdCtrl: _clientIdCtrl,
      secretCtrl: _secretCtrl,
      inCollegamento: _inCollegamento,
      errore: _errore,
      onCollega: _collega,
    );
  }
}

class _ConnessaView extends StatelessWidget {
  final StatoSincronizzazione sync;
  final VoidCallback onSync;
  final VoidCallback onDisconnetti;

  const _ConnessaView({
    required this.sync,
    required this.onSync,
    required this.onDisconnetti,
  });

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cloud_done_outlined, color: Colors.green[700]),
          title: const Text('Google Drive collegato'),
          subtitle: sync.errore != null
              ? Text('Errore: ${sync.errore}',
                  style: TextStyle(color: schema.error))
              : sync.ultimaSync != null
              ? Text(
                  'Ultima sync: ${_orario(sync.ultimaSync!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : const Text('Sincronizzazione in corso…'),
          trailing: sync.inCorso
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: 'Forza sincronizzazione',
                  icon: const Icon(Icons.sync),
                  onPressed: onSync,
                ),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onDisconnetti,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Disconnetti Drive'),
        ),
      ],
    );
  }

  static String _orario(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _CollegaView extends StatelessWidget {
  final TextEditingController clientIdCtrl;
  final TextEditingController secretCtrl;
  final bool inCollegamento;
  final String? errore;
  final VoidCallback onCollega;

  const _CollegaView({
    required this.clientIdCtrl,
    required this.secretCtrl,
    required this.inCollegamento,
    required this.errore,
    required this.onCollega,
  });

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cloud_off_outlined, color: schema.outline),
          title: const Text('Google Drive non collegato'),
          subtitle: const Text(
            'Serve un Client ID OAuth "Desktop" dal tuo progetto Google Cloud.',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: clientIdCtrl,
          decoration: const InputDecoration(
            labelText: 'Client ID',
            hintText: '12345-abc.apps.googleusercontent.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: secretCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Client Secret',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lascia Client Secret vuoto se usi un client OAuth "pubblico".',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: schema.onSurfaceVariant,
          ),
        ),
        if (errore != null) ...[
          const SizedBox(height: 8),
          Text(
            errore!,
            style: TextStyle(color: schema.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: inCollegamento ? null : onCollega,
          icon: inCollegamento
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_browser_outlined),
          label: Text(
            inCollegamento
                ? 'Apertura browser…'
                : 'Collega Drive (apre il browser)',
          ),
        ),
      ],
    );
  }
}

// ---- Esporta CSV -----------------------------------------------------------

class _EsportaCsvButton extends ConsumerStatefulWidget {
  const _EsportaCsvButton();

  @override
  ConsumerState<_EsportaCsvButton> createState() => _EsportaCsvButtonState();
}

class _EsportaCsvButtonState extends ConsumerState<_EsportaCsvButton> {
  bool _inCorso = false;

  Future<void> _esporta() async {
    setState(() => _inCorso = true);
    try {
      final esami = await ref.read(esameRepositoryProvider).esami();
      if (esami.isEmpty) {
        _mostraSnackbar('Nessun esame da esportare');
        return;
      }
      await ref.read(driveRepositoryProvider).esportaCsv(esami);
      _mostraSnackbar(
        'CSV esportato in Google Drive › Esami del Sangue/export/',
        errore: false,
      );
    } on DriveRepositoryException catch (e) {
      _mostraSnackbar('Errore Drive: ${e.messaggio}', errore: true);
    } catch (e) {
      _mostraSnackbar('Errore export: $e', errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  void _mostraSnackbar(String testo, {bool errore = false}) {
    if (!mounted) return;
    final schema = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testo),
        backgroundColor: errore ? schema.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _inCorso ? null : _esporta,
      icon: _inCorso
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
      label: const Text('Esporta tutti i dati come CSV'),
    );
  }
}
