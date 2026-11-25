import '../domain/broker.dart';

abstract interface class BrokerRepository {
  /// Emette la generazione attiva completa, oppure null se non ne esiste una
  /// (integrazione mai usata o disattivata). Errore se la generazione attiva
  /// non e valida: non si ricade su dati parziali.
  Stream<RilevazioneBroker?> osservaAttiva();
}
