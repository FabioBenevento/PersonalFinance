import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';

abstract interface class BrokerRepository {
  /// Emette la generazione attiva completa, oppure null se non ne esiste una
  /// (integrazione mai usata o disattivata). Errore se la generazione attiva
  /// non e valida: non si ricade su dati parziali.
  Stream<RilevazioneBroker?> osservaAttiva();

  /// Associazioni per id conto; i conti senza documento non compaiono.
  Stream<Map<String, AssociazioniConto>> osservaAssociazioni();

  /// Salva [nuove] se la revisione salvata e ancora [nuove].revisione - 1;
  /// altrimenti ValidazioneException (modifica concorrente).
  Future<void> salvaAssociazioni(String contoId, AssociazioniConto nuove);
}
