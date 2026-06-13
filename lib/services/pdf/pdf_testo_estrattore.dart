import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

class PdfTestoEstrattoreException implements Exception {
  final String messaggio;

  const PdfTestoEstrattoreException(this.messaggio);

  @override
  String toString() => 'PdfTestoEstrattoreException: $messaggio';
}

/// Estrae il testo leggibile da un PDF senza rasterizzare le pagine.
/// Funziona solo su PDF con layer testuale; per PDF scansionati (immagini pure)
/// lancia [PdfTestoEstrattoreException] → usare la modalità Vision.
class PdfTestoEstrattore {
  Future<String> estraiTesto(Uint8List pdfBytes) async {
    final doc = await PdfDocument.openData(pdfBytes);
    final buffer = StringBuffer();
    try {
      for (int i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        final rawText = await page.loadText();
        if (rawText != null && rawText.fullText.isNotEmpty) {
          buffer.writeln(rawText.fullText);
        }
      }
    } finally {
      doc.dispose();
    }

    final risultato = buffer.toString().trim();
    if (risultato.isEmpty) {
      throw const PdfTestoEstrattoreException(
        'Nessun testo leggibile trovato nel PDF — '
        'il file potrebbe essere una scansione: prova la modalità Vision',
      );
    }
    return risultato;
  }
}
