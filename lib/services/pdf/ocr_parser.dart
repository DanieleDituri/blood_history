import '../../models/range_riferimento.dart';
import '../../models/valore_esame.dart';
import '../../repositories/vision_repository.dart';

/// Parser rule-based per referti ematochimici in formato testo.
///
/// Funziona senza LLM: analizza ogni riga cercando il pattern
/// "nome   valore   unità   range" tipico dei referti tabulari italiani.
/// Funziona bene su PDF con layer testuale (non su scansioni pure).
class OcrParser {
  // Primo numero significativo della riga (non parte di date gg/mm/aaaa).
  static final _numRegex = RegExp(
    r'(?<![/\d,\.])(\d{1,5}(?:[.,]\d{1,4})?)(?![/\d])',
  );

  // Unità di misura: es. mg/dL, g/L, U/L, %, mmol/L, pg, fL, x10^3/μL …
  static final _unitRegex = RegExp(
    r'^([A-Za-zμΩ%°×x][A-Za-z0-9μΩ%°×/\-\^\.]{0,20})\s*(.*)',
  );

  // Range: 70-100, 70,0-100,5, 70 – 100
  static final _rangeRegex = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*[-–]\s*(\d+(?:[.,]\d+)?)',
  );

  // Data: gg/mm/aaaa o gg.mm.aaaa
  static final _dateRegex = RegExp(
    r'\b(\d{1,2})[/.](\d{1,2})[/.](\d{2,4})\b',
  );

  // Parole che indicano righe di intestazione da ignorare.
  static const _skipWords = {
    'esame', 'parametro', 'risultato', 'valore', 'valori',
    'riferimento', 'normale', 'unità', 'unita', 'data', 'ora',
    'referto', 'paziente', 'laboratorio', 'pagina', 'firma',
    'medico', 'codice', 'campione', 'materiale', 'metodo',
    'note', 'commento', 'sede', 'indirizzo',
  };

  static RisultatoEstrazione parseTesto(String testo) {
    final data = _estraiData(testo);
    final valori = <ValoreEsame>[];
    final seen = <String>{};

    for (final riga in testo.split('\n')) {
      final v = _parseRiga(riga.trim());
      if (v != null && seen.add(v.nome.toLowerCase())) {
        valori.add(v);
      }
    }

    return RisultatoEstrazione(valori: valori, data: data);
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  static DateTime? _estraiData(String testo) {
    for (final m in _dateRegex.allMatches(testo)) {
      final g = int.parse(m.group(1)!);
      final mm = int.parse(m.group(2)!);
      var a = int.parse(m.group(3)!);
      if (a < 100) a += 2000;
      if (mm < 1 || mm > 12 || g < 1 || g > 31) continue;
      try {
        final dt = DateTime(a, mm, g);
        final ora = DateTime.now();
        if (!dt.isAfter(ora) && dt.year >= 2000) return dt;
      } catch (_) {}
    }
    return null;
  }

  // ── Riga ──────────────────────────────────────────────────────────────────

  static ValoreEsame? _parseRiga(String riga) {
    if (riga.length < 4 || riga.length > 250) return null;

    final numMatch = _numRegex.firstMatch(riga);
    if (numMatch == null) return null;

    final nomeCandidato = riga.substring(0, numMatch.start).trim();
    if (!_nomeValido(nomeCandidato)) return null;

    final valoreStr = numMatch.group(1)!.replaceAll(',', '.');
    final valore = double.tryParse(valoreStr);
    if (valore == null || valore > 99999) return null;

    final resto = riga.substring(numMatch.end).trim();
    String unita = '';
    String rangeStr = '';

    final unitMatch = _unitRegex.firstMatch(resto);
    if (unitMatch != null) {
      unita = unitMatch.group(1) ?? '';
      rangeStr = unitMatch.group(2) ?? '';
    }

    double? min, max;
    final rm = _rangeRegex.firstMatch(rangeStr);
    if (rm != null) {
      min = double.tryParse(rm.group(1)!.replaceAll(',', '.'));
      max = double.tryParse(rm.group(2)!.replaceAll(',', '.'));
    }

    return ValoreEsame(
      nome: _normalizzaNome(nomeCandidato),
      valore: valore,
      unita: unita,
      range: RangeRiferimento(min: min, max: max),
    );
  }

  static bool _nomeValido(String nome) {
    if (nome.length < 2 || nome.length > 80) return false;
    // Scarta righe che sono solo cifre/simboli (es. date, codici)
    if (RegExp(r'^[\d\s/\-\.\(\)]+$').hasMatch(nome)) return false;
    // Scarta intestazioni di colonna
    final lower = nome.toLowerCase();
    if (_skipWords.any((w) => lower == w || lower.startsWith('$w '))) {
      return false;
    }
    return true;
  }

  static String _normalizzaNome(String nome) => nome
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[\s:\-]+$'), '')
      .trim();
}
