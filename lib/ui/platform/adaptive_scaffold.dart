import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// Scaffold di schermata adattivo: stessa API su tutte le piattaforme,
/// shell diversa. Il [body] (layout interno della schermata) passa
/// invariato.
///
/// - **Android** — [Scaffold] + [AppBar] Material 3.
/// - **macOS** — [Scaffold] trasparente sopra un gradiente, così le
///   superfici liquid glass hanno uno sfondo da rifrangere.
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
    final schema = Theme.of(context).colorScheme;
    return DecoratedBox(
      // Gradiente di sfondo: dà profondità al blur delle superfici glass.
      // Toni neutri di superficie: una tinta colorata qui impasta tutta
      // la schermata (testo, barre, card).
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [schema.surfaceContainerLowest, schema.surfaceContainerHigh],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(titolo), actions: azioni),
        body: body,
      ),
    );
  }
}
