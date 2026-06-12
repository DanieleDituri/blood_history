import 'package:flutter/material.dart';

/// Stato di un valore rispetto al proprio range di riferimento.
///
/// - [inRange]: verde, il valore è dentro il range.
/// - [borderline]: giallo, il valore è fuori range ma entro il 10%
///   dell'ampiezza del range dal limite violato.
/// - [fuoriRange]: rosso, il valore è oltre la tolleranza del 10%.
/// - [sconosciuto]: il referto non riportava un range utilizzabile.
enum StatoValore {
  inRange,
  borderline,
  fuoriRange,
  sconosciuto;

  Color get colore => switch (this) {
    StatoValore.inRange => const Color(0xFF2E7D32),
    StatoValore.borderline => const Color(0xFFF9A825),
    StatoValore.fuoriRange => const Color(0xFFC62828),
    StatoValore.sconosciuto => const Color(0xFF757575),
  };

  String get etichetta => switch (this) {
    StatoValore.inRange => 'In range',
    StatoValore.borderline => 'Borderline',
    StatoValore.fuoriRange => 'Fuori range',
    StatoValore.sconosciuto => 'N/D',
  };
}
