import 'associazioni_broker.dart';
import 'voce.dart';

/// Saldo di una componente selezionata nell'anteprima: [voce] e la voce
/// destinazione com'era mostrata, [proposto] il nuovo saldo in centesimi.
class SaldoDaConfermare {
  const SaldoDaConfermare({
    required this.contoId,
    required this.componente,
    required this.voce,
    required this.proposto,
  });
  final String contoId;
  final ComponenteBroker componente;
  final Voce voce;
  final int proposto;
}

/// Conferma di un'anteprima esaminata. [operazioneId] identifica la conferma
/// per l'idempotenza; [associazioni] sono quelle dei conti selezionati come
/// viste nell'anteprima.
class ConfermaBroker {
  const ConfermaBroker({
    required this.operazioneId,
    required this.rilevazioneId,
    required this.associazioni,
    required this.saldi,
  });
  final String operazioneId;
  final String rilevazioneId;
  final Map<String, AssociazioniConto> associazioni;
  final List<SaldoDaConfermare> saldi;
}

/// L'anteprima non corrisponde piu allo stato del server: nulla e stato
/// scritto e serve una nuova anteprima.
class ConflittoConfermaException implements Exception {
  const ConflittoConfermaException(this.message);
  final String message;

  @override
  String toString() => message;
}
