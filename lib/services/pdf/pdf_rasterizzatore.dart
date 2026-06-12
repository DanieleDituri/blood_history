import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

/// Errore nella conversione del PDF in immagini.
class PdfRasterException implements Exception {
  final String messaggio;
  final Object? causa;

  const PdfRasterException(this.messaggio, [this.causa]);

  @override
  String toString() =>
      'PdfRasterException: $messaggio${causa != null ? ' ($causa)' : ''}';
}

/// Converte un PDF in un'immagine PNG per pagina, da mandare al modello
/// vision. Interfaccia iniettabile: nei test si usa un fake, l'app usa
/// [PdfrxRasterizzatore] (Pdfium).
abstract class PdfRasterizzatore {
  Future<List<Uint8List>> renderizzaPagine(
    Uint8List pdf, {
    void Function(int pagina, int totale)? onProgresso,
  });
}

class PdfrxRasterizzatore implements PdfRasterizzatore {
  /// 2x dei punti PDF (72dpi → 144dpi): leggibile per il modello senza
  /// produrre base64 enormi.
  static const _scala = 2.0;

  /// Lato massimo in pixel: i modelli vision tanto ridimensionano, oltre
  /// questa soglia si spreca solo banda e contesto.
  static const _latoMassimo = 2048.0;

  static bool _inizializzato = false;

  @override
  Future<List<Uint8List>> renderizzaPagine(
    Uint8List pdf, {
    void Function(int pagina, int totale)? onProgresso,
  }) async {
    if (!_inizializzato) {
      await pdfrxFlutterInitialize();
      _inizializzato = true;
    }

    final PdfDocument documento;
    try {
      documento = await PdfDocument.openData(pdf);
    } catch (e) {
      throw PdfRasterException('PDF non leggibile o corrotto', e);
    }

    try {
      final pagine = <Uint8List>[];
      final totale = documento.pages.length;
      if (totale == 0) {
        throw const PdfRasterException('Il PDF non contiene pagine');
      }
      for (var i = 0; i < totale; i++) {
        onProgresso?.call(i + 1, totale);
        pagine.add(await _renderizzaPagina(documento.pages[i]));
      }
      return pagine;
    } finally {
      await documento.dispose();
    }
  }

  Future<Uint8List> _renderizzaPagina(PdfPage pagina) async {
    final latoMaggiore =
        (pagina.width > pagina.height ? pagina.width : pagina.height) * _scala;
    final scala = latoMaggiore > _latoMassimo
        ? _scala * _latoMassimo / latoMaggiore
        : _scala;

    final immagine = await pagina.render(
      fullWidth: pagina.width * scala,
      fullHeight: pagina.height * scala,
      backgroundColor: 0xFFFFFFFF, // pagine trasparenti → sfondo bianco
    );
    if (immagine == null) {
      throw PdfRasterException(
        'Rendering della pagina ${pagina.pageNumber} fallito',
      );
    }
    try {
      final uiImage = await immagine.createImage();
      try {
        final png = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) {
          throw PdfRasterException(
            'Codifica PNG della pagina ${pagina.pageNumber} fallita',
          );
        }
        return png.buffer.asUint8List();
      } finally {
        uiImage.dispose();
      }
    } finally {
      immagine.dispose();
    }
  }
}
