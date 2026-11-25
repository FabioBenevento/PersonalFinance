import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';
import '../domain/conferma_broker.dart';

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

  /// Applica online, in un'unica transazione, i saldi di [conferma] e la
  /// ricevuta, solo se rilevazione attiva, associazioni e voci coincidono con
  /// l'anteprima; altrimenti [ConflittoConfermaException] senza scritture.
  /// La stessa operazione gia applicata non viene riapplicata (ritorna false;
  /// true se applicata ora). Mai accodata offline: senza rete fallisce.
  Future<bool> confermaSaldi(ConfermaBroker conferma);
}
