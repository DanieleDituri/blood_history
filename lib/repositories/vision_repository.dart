import 'dart:convert';
import 'dart:typed_data';

import '../models/range_riferimento.dart';
import '../models/valore_esame.dart';
import '../services/vision/vision_client.dart';

/// Il modello ha risposto ma non è stato possibile estrarne JSON valido,
/// nemmeno dopo il retry a temperatura 0: la UI deve offrire
/// l'inserimento manuale.
class EstrazioneNonValidaException implements Exception {
  final String rispostaGrezza;

  const EstrazioneNonValidaException(this.rispostaGrezza);

  @override
  String toString() =>
      'EstrazioneNonValidaException: il modello non ha prodotto JSON valido';
}

/// Risultato dell'estrazione da una o più pagine.
///
/// [data] è la data del prelievo letta dal referto (null se il modello
/// non l'ha trovata o non era leggibile).
/// [analisi] è il commento in linguaggio naturale generato dal LLM dopo
/// l'estrazione (null se non disponibile o se la chiamata è fallita).
class RisultatoEstrazione {
  final List<ValoreEsame> valori;
  final DateTime? data;
  final String? analisi;

  const RisultatoEstrazione({required this.valori, this.data, this.analisi});
}

/// Estrazione dei valori da un referto tramite modello vision locale.
///
/// La strategia (LM Studio o Ollama) è il [VisionClient] iniettato.
/// Pipeline per ogni richiesta: prompt fisso + immagini → testo →
/// parsing JSON tollerante (code fence, testo attorno). Se il parsing
/// fallisce si ritenta una volta a temperatura 0; se fallisce ancora,
/// [EstrazioneNonValidaException].
class VisionRepository {
  /// Prompt concordato con i modelli — include la richiesta della data.
  static const promptEstrazione =
      'Sei un assistente medico. Analizza questo referto del sangue. '
      'Estrai la data del prelievo (o della firma del referto) e tutti i '
      'valori in formato JSON. '
      'Formato: {"data": "YYYY-MM-DD", "valori": [{"nome": "...", '
      '"valore": 0.0, "unita": "...", "range_min": 0.0, "range_max": 0.0}]}. '
      'Se la data non è leggibile ometti il campo "data". '
      'Restituisci SOLO il JSON, nessun testo aggiuntivo.';

  /// Prompt per l'estrazione da testo grezzo del PDF (modalità OCR desktop).
  static const promptEstrazioneTesto =
      'Sei un assistente medico. Leggi il seguente testo di un referto del '
      'sangue ed estrai la data del prelievo e tutti i valori in formato JSON. '
      'Formato: {"data": "YYYY-MM-DD", "valori": [{"nome": "...", '
      '"valore": 0.0, "unita": "...", "range_min": 0.0, "range_max": 0.0}]}. '
      'Se la data non è leggibile ometti il campo "data". '
      'Restituisci SOLO il JSON, nessun testo aggiuntivo.\n\nTesto del referto:\n';

  /// Prompt per l'analisi in linguaggio naturale dei valori estratti.
  static const _promptAnalisi =
      'Sei un assistente medico. Analizza questi valori di un esame del sangue '
      'e fornisci un commento breve in italiano (3-5 frasi), parlando '
      'direttamente al paziente. Spiega i risultati in linguaggio semplice, '
      'segnala eventuali valori fuori range o da tenere d\'occhio, e concludi '
      'con un consiglio generale. Non fare diagnosi, ma orienta il paziente.\n\n'
      'Valori:\n';

  static const _maxPagineInsieme = 2;
  static const _temperaturaPrimoTentativo = 0.2;

  final VisionClient _client;

  VisionRepository(this._client);

  String get nomeBackend => _client.nomeBackend;

  /// Estrae i valori e la data dalle pagine del referto.
  ///
  /// [onProgresso] riceve (pagina corrente, totale) prima di ogni
  /// richiesta al modello.
  Future<RisultatoEstrazione> estraiValori(
    List<Uint8List> pagine, {
    void Function(int pagina, int totale)? onProgresso,
  }) async {
    if (pagine.isEmpty) return const RisultatoEstrazione(valori: []);

    if (pagine.length <= _maxPagineInsieme) {
      onProgresso?.call(1, 1);
      return _estraiConRetry(pagine);
    }

    // Referto lungo: una pagina per volta, poi unione senza duplicati.
    final visti = <String>{};
    final valori = <ValoreEsame>[];
    DateTime? dataEstratta;

    for (var i = 0; i < pagine.length; i++) {
      onProgresso?.call(i + 1, pagine.length);
      final risultato = await _estraiConRetry([pagine[i]]);
      dataEstratta ??= risultato.data; // prima data trovata vince
      for (final v in risultato.valori) {
        if (visti.add(v.nome.toLowerCase().trim())) valori.add(v);
      }
    }
    return RisultatoEstrazione(valori: valori, data: dataEstratta);
  }

  /// Estrae valori e data da testo grezzo del PDF (modalità OCR desktop).
  ///
  /// Invia il testo come prompt testuale al LLM (senza immagini), quindi
  /// usa lo stesso parser JSON di [estraiValori].
  Future<RisultatoEstrazione> estraiDaTesto(String testoPdf) async {
    final prompt = '$promptEstrazioneTesto$testoPdf';
    final risposta = await _client.generaTesto(
      prompt: prompt,
      immaginiPng: const [],
      temperatura: _temperaturaPrimoTentativo,
    );
    try {
      return parseRisposta(risposta);
    } on FormatException {
      final risposta2 = await _client.generaTesto(
        prompt: prompt,
        immaginiPng: const [],
        temperatura: 0,
      );
      try {
        return parseRisposta(risposta2);
      } on FormatException {
        throw EstrazioneNonValidaException(risposta2);
      }
    }
  }

  /// Genera un'analisi in linguaggio naturale dei [valori] estratti.
  ///
  /// Restituisce null in caso di errore (la feature è non bloccante).
  Future<String?> analisiValori(List<ValoreEsame> valori) async {
    if (valori.isEmpty) return null;
    final elenco = valori.map((v) {
      final range =
          (v.range.min != null && v.range.max != null)
              ? ' (range: ${v.range.min}-${v.range.max} ${v.unita})'
              : '';
      return '- ${v.nome}: ${v.valore} ${v.unita}$range';
    }).join('\n');
    final prompt = '$_promptAnalisi$elenco';
    try {
      return await _client.generaTesto(
        prompt: prompt,
        immaginiPng: const [],
        temperatura: 0.4,
      );
    } catch (_) {
      return null;
    }
  }

  Future<RisultatoEstrazione> _estraiConRetry(
    List<Uint8List> immagini,
  ) async {
    final primaRisposta = await _client.generaTesto(
      prompt: promptEstrazione,
      immaginiPng: immagini,
      temperatura: _temperaturaPrimoTentativo,
    );
    try {
      return parseRisposta(primaRisposta);
    } on FormatException {
      final secondaRisposta = await _client.generaTesto(
        prompt: promptEstrazione,
        immaginiPng: immagini,
        temperatura: 0,
      );
      try {
        return parseRisposta(secondaRisposta);
      } on FormatException {
        throw EstrazioneNonValidaException(secondaRisposta);
      }
    }
  }

  /// Estrae valori e data dal testo del modello.
  ///
  /// Tollera code fence, testo attorno al JSON, virgole nei numeri,
  /// range mancanti, date in vari formati italiani/ISO.
  /// Lancia [FormatException] se non c'è JSON utilizzabile.
  static RisultatoEstrazione parseRisposta(String risposta) {
    final json = _estraiOggettoJson(risposta);
    final valoriGrezzi = json['valori'];
    if (valoriGrezzi is! List) {
      throw const FormatException('Manca la lista "valori"');
    }

    final valori = <ValoreEsame>[];
    for (final grezzo in valoriGrezzi) {
      if (grezzo is! Map<String, dynamic>) continue;
      final nome = (grezzo['nome'] as String?)?.trim();
      final valore = _aNumero(grezzo['valore']);
      if (nome == null || nome.isEmpty || valore == null) continue;
      valori.add(
        ValoreEsame(
          nome: nome,
          valore: valore,
          unita: (grezzo['unita'] as String?)?.trim() ?? '',
          range: RangeRiferimento(
            min: _aNumero(grezzo['range_min']),
            max: _aNumero(grezzo['range_max']),
          ),
        ),
      );
    }

    return RisultatoEstrazione(
      valori: valori,
      data: _aData(json['data']),
    );
  }

  static Map<String, dynamic> _estraiOggettoJson(String testo) {
    final inizio = testo.indexOf('{');
    final fine = testo.lastIndexOf('}');
    if (inizio < 0 || fine <= inizio) {
      throw const FormatException('Nessun oggetto JSON nella risposta');
    }
    final candidato = testo.substring(inizio, fine + 1);
    final decodificato = jsonDecode(candidato);
    if (decodificato is! Map<String, dynamic>) {
      throw const FormatException('Il JSON non è un oggetto');
    }
    return decodificato;
  }

  static double? _aNumero(Object? grezzo) {
    if (grezzo is num) return grezzo.toDouble();
    if (grezzo is String) {
      final pulito = grezzo
          .replaceAll(',', '.')
          .replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(pulito);
    }
    return null;
  }

  /// Converte la stringa data del modello in [DateTime].
  ///
  /// Accetta: `YYYY-MM-DD`, `DD/MM/YYYY`, `DD/MM/YY`, `DD.MM.YYYY`.
  /// Scarta date future o precedenti all'anno 2000.
  static DateTime? _aData(Object? grezzo) {
    if (grezzo is! String) return null;
    final s = grezzo.trim();
    if (s.isEmpty) return null;

    DateTime? candidata;

    // ISO YYYY-MM-DD
    candidata = DateTime.tryParse(s);

    // DD/MM/YYYY o DD/MM/YY
    if (candidata == null) {
      final p = s.split('/');
      if (p.length == 3) {
        final g = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        var a = int.tryParse(p[2]);
        if (g != null && m != null && a != null) {
          if (a < 100) a += 2000;
          try {
            candidata = DateTime(a, m, g);
          } catch (_) {}
        }
      }
    }

    // DD.MM.YYYY
    if (candidata == null) {
      final p = s.split('.');
      if (p.length == 3) {
        final g = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        var a = int.tryParse(p[2]);
        if (g != null && m != null && a != null) {
          if (a < 100) a += 2000;
          try {
            candidata = DateTime(a, m, g);
          } catch (_) {}
        }
      }
    }

    if (candidata == null) return null;
    // Scarta date impossibili
    final ora = DateTime.now();
    if (candidata.isAfter(ora) || candidata.year < 2000) return null;
    return DateTime(candidata.year, candidata.month, candidata.day);
  }
}
