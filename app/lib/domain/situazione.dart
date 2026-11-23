import 'importo.dart';
import 'voce.dart';

class Situazione {
  const Situazione(this.voci);

  final List<Voce> voci;

  int totaleGruppo(Gruppo g) => [
    for (final v in voci)
      if (v.gruppo == g) v.saldoCentesimi,
  ].fold(0, (a, b) => a + b);

  int get totale => Gruppo.values.fold(0, (s, g) => s + totaleGruppo(g));

  String percentualeVoce(Voce v) =>
      scriviPercentuale(v.saldoCentesimi, totaleGruppo(v.gruppo));

  String percentualeGruppo(Gruppo g) =>
      scriviPercentuale(totaleGruppo(g), totale);
}
