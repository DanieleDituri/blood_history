import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/costanti.dart';
import '../../providers/providers.dart';
import '../../services/android/android_import_service.dart';
import '../../services/backup/backup_service.dart';
import '../../ui/platform/adaptive_scaffold.dart';

class ImpostazioniScreen extends ConsumerStatefulWidget {
  const ImpostazioniScreen({super.key});

  @override
  ConsumerState<ImpostazioniScreen> createState() => _ImpostazioniState();
}

class _ImpostazioniState extends ConsumerState<ImpostazioniScreen> {
  late TextEditingController _endpoint;
  String _tipo = 'lmstudio';
  String? _modelloSelezionato;
  List<String> _modelli = [];
  bool _caricandoModelli = false;
  bool _caricato = false;
  bool? _endpointOk; // null = non testato, true = ok, false = errore

  @override
  void initState() {
    super.initState();
    _endpoint = TextEditingController();
    _carica();
  }

  Future<void> _carica() async {
    final prefs = await SharedPreferences.getInstance();
    final tipo = prefs.getString(Costanti.prefTipoModello) ?? 'lmstudio';
    final defaultEndpoint = tipo == 'ollama'
        ? Costanti.endpointOllama
        : Costanti.endpointLmStudio;
    final defaultModello = tipo == 'ollama'
        ? Costanti.modelloDefaultOllama
        : Costanti.modelloDefaultLmStudio;
    setState(() {
      _tipo = tipo;
      _endpoint.text =
          prefs.getString(Costanti.prefEndpointModello) ?? defaultEndpoint;
      _modelloSelezionato =
          prefs.getString(Costanti.prefNomeModello) ?? defaultModello;
      _caricato = true;
    });
    await _caricaModelli();
  }

  Future<void> _cambiaTipo(String tipo) async {
    final defaultEndpoint = tipo == 'ollama'
        ? Costanti.endpointOllama
        : Costanti.endpointLmStudio;
    setState(() {
      _tipo = tipo;
      _endpoint.text = defaultEndpoint;
      _modelli = [];
      _modelloSelezionato = null;
      _endpointOk = null;
    });
    await _caricaModelli();
  }

  Future<void> _caricaModelli() async {
    setState(() {
      _caricandoModelli = true;
      _endpointOk = null;
    });
    try {
      final url = _tipo == 'ollama'
          ? '${_endpoint.text}/api/tags'
          : '${_endpoint.text}/models';
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode < 400) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        List<String> nomi;
        if (_tipo == 'ollama') {
          final lista = json['models'] as List? ?? [];
          nomi = lista.map((m) => (m as Map)['name'] as String).toList();
        } else {
          final lista = json['data'] as List? ?? [];
          nomi = lista.map((m) => (m as Map)['id'] as String).toList();
        }
        nomi.sort();
        if (mounted) {
          setState(() {
            _endpointOk = true;
            _modelli = nomi;
            if (_modelloSelezionato != null &&
                !nomi.contains(_modelloSelezionato)) {
              _modelli = [_modelloSelezionato!, ...nomi];
            }
          });
        }
      } else {
        if (mounted) setState(() => _endpointOk = false);
      }
    } catch (_) {
      if (mounted) setState(() => _endpointOk = false);
    } finally {
      if (mounted) setState(() => _caricandoModelli = false);
    }
  }

  Future<void> _salva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Costanti.prefTipoModello, _tipo);
    await prefs.setString(Costanti.prefEndpointModello, _endpoint.text.trim());
    await prefs.setString(
      Costanti.prefNomeModello,
      _modelloSelezionato?.trim() ?? '',
    );
    ref.invalidate(configModelloProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impostazioni salvate')),
      );
    }
  }

  @override
  void dispose() {
    _endpoint.dispose();
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
              onCambia: _cambiaTipo,
            ),
            const SizedBox(height: 16),
            const _ModalitaDesktopSelector(),
            const SizedBox(height: 16),
            // Endpoint unico che cambia col selettore
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _endpoint,
                    decoration: InputDecoration(
                      labelText: _tipo == 'ollama'
                          ? 'Endpoint Ollama'
                          : 'Endpoint LM Studio',
                      border: const OutlineInputBorder(),
                      suffixIcon: _endpointOk == null
                          ? null
                          : Icon(
                              _endpointOk!
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: _endpointOk! ? Colors.green : Theme.of(context).colorScheme.error,
                            ),
                    ),
                    onEditingComplete: _caricaModelli,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _caricaModelli,
                  child: _caricandoModelli
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Selezione modello: dropdown se la lista è disponibile
            if (_modelli.isNotEmpty)
              DropdownMenu<String>(
                initialSelection: _modelloSelezionato,
                expandedInsets: EdgeInsets.zero,
                label: const Text('Modello'),
                dropdownMenuEntries: _modelli
                    .map((m) => DropdownMenuEntry(value: m, label: m))
                    .toList(),
                onSelected: (v) => setState(() => _modelloSelezionato = v),
              )
            else
              TextFormField(
                key: ValueKey(_modelloSelezionato),
                initialValue: _modelloSelezionato,
                decoration: InputDecoration(
                  labelText: 'Modello',
                  hintText: _tipo == 'ollama'
                      ? 'es. qwen3-vl:8b'
                      : 'es. qwen/qwen3-vl-8b',
                  border: const OutlineInputBorder(),
                  helperText: _caricandoModelli
                      ? 'Caricamento modelli…'
                      : 'Endpoint non raggiungibile — inserisci il nome manualmente',
                ),
                onChanged: (v) => _modelloSelezionato = v,
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salva,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva impostazioni'),
            ),
            const SizedBox(height: 24),
          ],
          _sezione('Backup locale'),
          const _BackupSection(),
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

// ---- Sezione Backup locale --------------------------------------------------

class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  String? _cartella;
  bool _inCorso = false;
  String? _messaggio;
  bool _messaggioErrore = false;

  @override
  void initState() {
    super.initState();
    BackupService.cartellaBackup().then((c) {
      if (mounted) setState(() => _cartella = c);
    });
  }

  Future<void> _scegli() async {
    final percorso = await BackupService.scegliCartella();
    if (percorso != null && mounted) setState(() => _cartella = percorso);
  }

  Future<void> _esporta() async {
    if (_cartella == null) {
      await _scegli();
      if (_cartella == null) return;
    }
    setState(() { _inCorso = true; _messaggio = null; });
    try {
      final esami = await ref.read(esameRepositoryProvider).esami();
      if (esami.isEmpty) {
        _mostra('Nessun esame da esportare');
        return;
      }
      final n = await BackupService.esportaTutti(esami);
      _mostra('$n esami esportati in $_cartella/esami/', errore: false);
    } on BackupException catch (e) {
      _mostra(e.messaggio, errore: true);
    } catch (e) {
      _mostra('Errore: $e', errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _importa() async {
    if (_cartella == null) {
      await _scegli();
      if (_cartella == null) return;
    }
    setState(() { _inCorso = true; _messaggio = null; });
    try {
      final esami = await BackupService.importaDaCartella();
      if (esami.isEmpty) {
        _mostra('Nessun file JSON trovato nella cartella backup');
        return;
      }
      final repo = ref.read(esameRepositoryProvider);
      for (final esame in esami) {
        await repo.salvaEsame(esame);
      }
      ref.invalidate(snapshotProvider);
      _mostra('${esami.length} esami importati', errore: false);
    } on BackupException catch (e) {
      _mostra(e.messaggio, errore: true);
    } catch (e) {
      _mostra('Errore: $e', errore: true);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  void _mostra(String testo, {bool errore = false}) {
    if (!mounted) return;
    setState(() { _messaggio = testo; _messaggioErrore = errore; });
  }

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _cartella != null ? Icons.folder_outlined : Icons.folder_off_outlined,
            color: _cartella != null ? Colors.green[700] : schema.outline,
          ),
          title: Text(_cartella != null ? 'Cartella backup' : 'Nessuna cartella scelta'),
          subtitle: _cartella != null
              ? Text(_cartella!, style: Theme.of(context).textTheme.bodySmall)
              : const Text('Scegli una cartella dove salvare i tuoi esami'),
          trailing: TextButton(
            onPressed: _scegli,
            child: const Text('Cambia'),
          ),
        ),
        if (_messaggio != null) ...[
          const SizedBox(height: 4),
          Text(
            _messaggio!,
            style: TextStyle(
              fontSize: 12,
              color: _messaggioErrore ? schema.error : Colors.green[700],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _inCorso ? null : _esporta,
                icon: _inCorso
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_outlined),
                label: const Text('Esporta backup'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _inCorso ? null : _importa,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Importa backup'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
