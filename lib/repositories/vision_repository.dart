import 'dart:convert';
import 'dart:typed_data';

import '../models/range_riferimento.dart';
import '../models/valore_esame.dart';
import '../services/vision/vision_client.dart';

/// Il modello ha risposto ma non è stato possibile estrarne JSON valido,
/// nemmeno dopo il retry a temperatura 0: la UI deve offrire
/// l'inserimento manuale.
class EstrazioneNonValidaException implements Exception {
  /// L'ultima risposta grezza del modello, per diagnostica.
  final String rispostaGrezza;

  const EstrazioneNonValidaException(this.rispostaGrezza);

  @override
  String toString() =>
      'EstrazioneNonValidaException: il modello non ha prodotto JSON valido';
}

/// Estrazione dei valori da un referto tramite modello vision locale.
///
/// La strategia (LM Studio o Ollama) è il [VisionClient] iniettato.
/// Pipeline per ogni richiesta: prompt fisso + immagini → testo →
/// parsing JSON tollerante (code fence, testo attorno). Se il parsing
/// fallisce si ritenta una volta a temperatura 0; se fallisce ancora,
/// [EstrazioneNonValidaException].
class VisionRepository {
  /// Prompt concordato con i modelli (da non modificare a cuor leggero:
  /// il parser si aspetta il formato che questo prompt chiede).
  static const promptEstrazione =
      'Sei un assistente medico. Analizza questo referto del sangue ed '
      'estrai tutti i valori in formato JSON. Per ogni parametro '
      'restituisci: nome (stringa), valore (numero), unita (stringa), '
      'range_min (numero), range_max (numero). Restituisci SOLO il JSON, '
      'nessun testo aggiuntivo. Formato: {"valori": [{"nome": "...", '
      '"valore": 0.0, "unita": "...", "range_min": 0.0, "range_max": 0.0}]}';

  /// Fino a questo numero di pagine si manda tutto in una richiesta
  /// sola; oltre, una pagina per volta (contesto e qualità migliori).
  static const _maxPagineInsieme = 2;

  static const _temperaturaPrimoTentativo = 0.2;

  final VisionClient _client;

  VisionRepository(this._client);

  String get nomeBackend => _client.nomeBackend;

  /// Estrae i valori dalle pagine del referto (una PNG per pagina).
  ///
  /// [onProgresso] riceve (pagina corrente, totale) prima di ogni
  /// richiesta al modello — con poche pagine viene chiamato una volta
  /// sola con (1, 1).
  Future<List<ValoreEsame>> estraiValori(
    List<Uint8List> pagine, {
    void Function(int pagina, int totale)? onProgresso,
  }) async {
    if (pagine.isEmpty) return const [];

    if (pagine.length <= _maxPagineInsieme) {
      onProgresso?.call(1, 1);
      return _estraiConRetry(pagine);
    }

    // Referto lungo: una pagina per volta, poi unione senza duplicati
    // (lo stesso parametro può comparire su più pagine, es. riporti).
    final visti = <String>{};
    final risultato = <ValoreEsame>[];
    for (var i = 0; i < pagine.length; i++) {
      onProgresso?.call(i + 1, pagine.length);
      final valori = await _estraiConRetry([pagine[i]]);
      for (final v in valori) {
        if (visti.add(v.nome.toLowerCase().trim())) risultato.add(v);
      }
    }
    return risultato;
  }

  Future<List<ValoreEsame>> _estraiConRetry(List<Uint8List> immagini) async {
    final primaRisposta = await _client.generaTesto(
      prompt: promptEstrazione,
      immaginiPng: immagini,
      temperatura: _temperaturaPrimoTentativo,
    );
    try {
      return parseRisposta(primaRisposta);
    } on FormatException {
      // Retry deterministico: a temperatura 0 i modelli rispettano
      // meglio il formato richiesto.
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

  /// Estrae la lista di valori dal testo del modello.
  ///
  /// Tollera i vizi tipici: code fence markdown, testo prima/dopo il
  /// JSON, numeri come stringhe con la virgola, range mancanti.
  /// Lancia [FormatException] se non c'è JSON utilizzabile.
  static List<ValoreEsame> parseRisposta(String risposta) {
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
      // Senza nome o valore numerico la riga è inutilizzabile: si scarta
      // invece di far fallire l'intero referto.
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
    return valori;
  }

  /// Trova e decodifica il primo oggetto JSON nel testo, ignorando code
  /// fence e chiacchiere del modello.
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

  /// Converte in double ciò che i modelli mettono nei campi numerici:
  /// numeri veri, stringhe ("5.2", "5,2", "< 0.5"), null.
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
}
