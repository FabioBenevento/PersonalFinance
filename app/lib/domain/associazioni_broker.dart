import 'voce.dart';

enum ComponenteBroker { liquidita, investimenti }

/// Destinazioni esplicite di un conto broker; [revisione] 0 = mai salvate.
class AssociazioniConto {
  const AssociazioniConto({
    this.revisione = 0,
    this.liquidita,
    this.investimenti,
  });
  final int revisione;
  final String? liquidita;
  final String? investimenti;

  String? destinazione(ComponenteBroker c) =>
      c == ComponenteBroker.liquidita ? liquidita : investimenti;
}

/// Associazioni nuove del conto, o [ValidazioneException] senza effetti.
AssociazioniConto associa({
  required Map<String, AssociazioniConto> tutte,
  required String contoId,
  required ComponenteBroker componente,
  required String voceId,
  required List<Voce> voci,
}) {
  final voce = voci.where((v) => v.id == voceId).firstOrNull;
  if (voce == null) throw const ValidazioneException('Voce non più esistente');
  if (voce.conDettaglio) {
    throw const ValidazioneException('La voce ha un dettaglio');
  }
  final gruppo = componente == ComponenteBroker.liquidita
      ? Gruppo.liquidita
      : Gruppo.investimenti;
  if (voce.gruppo != gruppo) {
    throw const ValidazioneException('Gruppo della voce non corretto');
  }
  for (final e in tutte.entries) {
    for (final c in ComponenteBroker.values) {
      if (e.value.destinazione(c) == voceId &&
          !(e.key == contoId && c == componente)) {
        throw const ValidazioneException('Voce già associata');
      }
    }
  }
  final corrente = tutte[contoId] ?? const AssociazioniConto();
  return AssociazioniConto(
    revisione: corrente.revisione + 1,
    liquidita: componente == ComponenteBroker.liquidita
        ? voceId
        : corrente.liquidita,
    investimenti: componente == ComponenteBroker.investimenti
        ? voceId
        : corrente.investimenti,
  );
}
