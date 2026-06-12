import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/range_riferimento.dart';
import '../../models/valore_esame.dart';
import '../../ui/platform/adaptive_button.dart';
import 'import_screen.dart' show SalvaEsame;

/// Anteprima editabile dei valori estratti: una riga per parametro
/// (nome, valore, unità, range min/max), più data dell'esame, aggiunta
/// manuale di parametri e salvataggio.
class TabellaValoriEditor extends StatefulWidget {
  final List<ValoreEsame> valoriIniziali;
  final String? avviso;
  final SalvaEsame onSalva;
  final VoidCallback onAnnulla;

  /// Data letta dal referto; se null l'editor usa la data odierna.
  final DateTime? dataIniziale;

  const TabellaValoriEditor({
    super.key,
    required this.valoriIniziali,
    this.avviso,
    required this.onSalva,
    required this.onAnnulla,
    this.dataIniziale,
  });

  @override
  State<TabellaValoriEditor> createState() => _TabellaValoriEditorState();
}

class _TabellaValoriEditorState extends State<TabellaValoriEditor> {
  final _formKey = GlobalKey<FormState>();
  final List<_RigaEditor> _righe = [];
  late DateTime _dataEsame;

  @override
  void initState() {
    super.initState();
    _dataEsame = widget.dataIniziale ?? DateTime.now();
    for (final valore in widget.valoriIniziali) {
      _righe.add(_RigaEditor.daValore(valore));
    }
    if (_righe.isEmpty) _righe.add(_RigaEditor.vuota());
  }

  @override
  void dispose() {
    for (final riga in _righe) {
      riga.dispose();
    }
    super.dispose();
  }

  Future<void> _scegliData() async {
    final scelta = await showDatePicker(
      context: context,
      initialDate: _dataEsame,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (scelta != null) setState(() => _dataEsame = scelta);
  }

  void _aggiungiRiga() => setState(() => _righe.add(_RigaEditor.vuota()));

  void _rimuoviRiga(_RigaEditor riga) {
    setState(() => _righe.remove(riga));
    riga.dispose();
  }

  Future<void> _salva() async {
    if (!_formKey.currentState!.validate()) return;
    final valori = [for (final riga in _righe) riga.aValore()];
    if (valori.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aggiungi almeno un parametro')),
      );
      return;
    }
    await widget.onSalva(valori, _dataEsame);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Data del prelievo: è la chiave dell'esame su Drive.
                InputChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(
                    'Esame del ${DateFormat('dd/MM/yyyy').format(_dataEsame)}',
                  ),
                  onPressed: _scegliData,
                ),
                if (widget.avviso != null)
                  Text(
                    widget.avviso!,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _IntestazioneTabella(stile: tema.textTheme.labelSmall),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _righe.length,
              itemBuilder: (context, i) => _RigaWidget(
                key: ObjectKey(_righe[i]),
                riga: _righe[i],
                onRimuovi: () => _rimuoviRiga(_righe[i]),
              ),
            ),
          ),
          // SafeArea: su macOS il padding inferiore è la barra glass
          // flottante, e i bottoni devono restarci sopra.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  AdaptiveButton(
                    etichetta: 'Aggiungi parametro',
                    icona: Icons.add,
                    onPressed: _aggiungiRiga,
                  ),
                  AdaptiveButton(
                    etichetta: 'Salva',
                    icona: Icons.save_outlined,
                    onPressed: _salva,
                  ),
                  AdaptiveButton(
                    etichetta: 'Annulla',
                    onPressed: widget.onAnnulla,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntestazioneTabella extends StatelessWidget {
  final TextStyle? stile;

  const _IntestazioneTabella({this.stile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Parametro', style: stile)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Valore', style: stile)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Unità', style: stile)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Min', style: stile)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text('Max', style: stile)),
          const SizedBox(width: 40), // spazio per il bottone elimina
        ],
      ),
    );
  }
}

/// I controller di testo di una riga della tabella.
class _RigaEditor {
  final TextEditingController nome;
  final TextEditingController valore;
  final TextEditingController unita;
  final TextEditingController rangeMin;
  final TextEditingController rangeMax;

  _RigaEditor._({
    required this.nome,
    required this.valore,
    required this.unita,
    required this.rangeMin,
    required this.rangeMax,
  });

  factory _RigaEditor.daValore(ValoreEsame v) => _RigaEditor._(
    nome: TextEditingController(text: v.nome),
    valore: TextEditingController(text: _numero(v.valore)),
    unita: TextEditingController(text: v.unita),
    rangeMin: TextEditingController(text: _numero(v.range.min)),
    rangeMax: TextEditingController(text: _numero(v.range.max)),
  );

  factory _RigaEditor.vuota() => _RigaEditor._(
    nome: TextEditingController(),
    valore: TextEditingController(),
    unita: TextEditingController(),
    rangeMin: TextEditingController(),
    rangeMax: TextEditingController(),
  );

  static String _numero(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  /// Parsa un numero accettando sia il punto che la virgola.
  static double? parsa(String testo) {
    final pulito = testo.trim().replaceAll(',', '.');
    return pulito.isEmpty ? null : double.tryParse(pulito);
  }

  ValoreEsame aValore() => ValoreEsame(
    nome: nome.text.trim(),
    valore: parsa(valore.text) ?? 0,
    unita: unita.text.trim(),
    range: RangeRiferimento(
      min: parsa(rangeMin.text),
      max: parsa(rangeMax.text),
    ),
  );

  void dispose() {
    nome.dispose();
    valore.dispose();
    unita.dispose();
    rangeMin.dispose();
    rangeMax.dispose();
  }
}

class _RigaWidget extends StatelessWidget {
  final _RigaEditor riga;
  final VoidCallback onRimuovi;

  const _RigaWidget({super.key, required this.riga, required this.onRimuovi});

  String? _validaNumero(String? testo, {bool obbligatorio = false}) {
    final t = testo?.trim() ?? '';
    if (t.isEmpty) return obbligatorio ? 'Richiesto' : null;
    return _RigaEditor.parsa(t) == null ? 'Numero non valido' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: riga.nome,
              decoration: const InputDecoration(
                hintText: 'es. Glicemia',
                isDense: true,
              ),
              validator: (t) =>
                  (t?.trim().isEmpty ?? true) ? 'Richiesto' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: riga.valore,
              decoration: const InputDecoration(hintText: '0', isDense: true),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (t) => _validaNumero(t, obbligatorio: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: riga.unita,
              decoration: const InputDecoration(
                hintText: 'mg/dL',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: riga.rangeMin,
              decoration: const InputDecoration(hintText: '—', isDense: true),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validaNumero,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: riga.rangeMax,
              decoration: const InputDecoration(hintText: '—', isDense: true),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validaNumero,
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: 'Rimuovi riga',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onRimuovi,
            ),
          ),
        ],
      ),
    );
  }
}
