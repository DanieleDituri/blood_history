import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/costanti.dart';
import '../../providers/providers.dart';
import '../../repositories/drive_repository.dart';
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
          _sezione('Modello Vision Locale'),
          _TipoModelloSelector(
            valore: _tipo,
            onCambia: (v) => setState(() => _tipo = v),
          ),
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
          _sezione('Google Drive'),
          _DriveSection(),
          const SizedBox(height: 16),
          _EsportaCsvButton(),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _salva,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salva impostazioni'),
          ),
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

class _DriveSection extends ConsumerWidget {
  const _DriveSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncNotifierProvider);
    final schema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Google Drive'),
          subtitle: sync.errore != null
              ? Text(
                  'Errore: ${sync.errore}',
                  style: TextStyle(color: schema.error),
                )
              : sync.ultimaSync != null
              ? Text(
                  'Ultima sync: ${_orario(sync.ultimaSync!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : const Text('Non sincronizzato'),
          trailing: sync.inCorso
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: 'Forza sync da Drive',
                  icon: const Icon(Icons.sync),
                  onPressed: () =>
                      ref.read(syncNotifierProvider.notifier).sincronizza(),
                ),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _disconnetti(context, ref),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Disconnetti Drive'),
        ),
      ],
    );
  }

  static String _orario(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> _disconnetti(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnetti Drive?'),
        content: const Text(
          'Le credenziali salvate verranno rimosse. '
          'Potrai riconnetterti in qualsiasi momento.',
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
    }
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
