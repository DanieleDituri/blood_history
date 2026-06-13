import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// Scaffold di schermata adattivo.
///
/// - **Android** — [Scaffold] + [AppBar] Material 3.
/// - **macOS** — nessun Material AppBar; toolbar nativa 52px allineata alla
///   zona traffic-light della sidebar. Titolo + azioni nel toolbar, poi body.
/// - **Windows** — [fluent.ScaffoldPage] con header Fluent.
class AdaptiveScaffold extends StatelessWidget {
  final String titolo;
  final List<Widget> azioni;
  final Widget body;

  const AdaptiveScaffold({
    super.key,
    required this.titolo,
    this.azioni = const [],
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return switch (AdaptivePlatform.corrente) {
      PiattaformaApp.android => Scaffold(
        appBar: AppBar(title: Text(titolo), actions: azioni),
        body: body,
      ),
      PiattaformaApp.macos => _ScaffoldMacos(
        titolo: titolo,
        azioni: azioni,
        body: body,
      ),
      PiattaformaApp.windows => fluent.ScaffoldPage(
        header: fluent.PageHeader(
          title: Text(titolo),
          commandBar: azioni.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: azioni),
        ),
        content: body,
      ),
    };
  }
}

/// Scaffold macOS HIG-compliant.
///
/// Non usa [AppBar] Material. In cima mostra [_MacosToolbar] (52px), allineata
/// verticalmente con la zona header della sidebar (stessa altezza). Sotto il
/// toolbar c'è il corpo della schermata con lo sfondo trasparente che lascia
/// vedere il gradiente globale della shell.
class _ScaffoldMacos extends StatelessWidget {
  final String titolo;
  final List<Widget> azioni;
  final Widget body;

  const _ScaffoldMacos({
    required this.titolo,
    required this.azioni,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MacosToolbar(titolo: titolo, azioni: azioni),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Toolbar HIG macOS.
///
/// - Altezza 52px: si allinea orizzontalmente con la zona header della sidebar
///   (che riserva 52px per i traffic-light + nome app), creando l'illusione di
///   una toolbar unificata che copre tutta la larghezza della finestra.
/// - Titolo: 15pt semibold, spacing negativo (SF Pro style).
/// - Azioni: destra, con icone borderless stile macOS nativo.
/// - Separatore inferiore: 0.5px per separare toolbar da contenuto
///   (come in Mail, Promemoria, Note).
class _MacosToolbar extends StatelessWidget {
  final String titolo;
  final List<Widget> azioni;

  const _MacosToolbar({required this.titolo, required this.azioni});

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final separatoreColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.10);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: separatoreColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            titolo,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: schema.onSurface,
            ),
          ),
          const Spacer(),
          if (azioni.isNotEmpty) ...[
            ...azioni,
          ],
        ],
      ),
    );
  }
}
