/// Costanti condivise dell'app.
class Costanti {
  Costanti._();

  static const nomeApp = 'EsamiTracker';

  // Struttura cartelle su Google Drive.
  static const cartellaDrive = 'Esami del Sangue';
  static const sottocartellaPdf = 'pdf';
  static const sottocartellaData = 'data';

  // Chiavi shared_preferences.
  static const prefEndpointModello = 'endpoint_modello';
  static const prefNomeModello = 'nome_modello';
  static const prefDriveClientId = 'drive_client_id';
  static const prefDriveClientSecret = 'drive_client_secret';
  static const prefCredenzialiDrive = 'drive_credentials';

  // Default per il modello vision locale (Sessione 2).
  static const endpointLmStudio = 'http://localhost:1234/v1';
  static const endpointOllama = 'http://localhost:11434/api';
}
