import 'fotografia_mensile.dart';
import 'mese.dart';
import 'voce.dart';

enum PeriodoAndamento { dodiciMesi, annoInCorso, treAnni, tutto }

/// Valori di un mese; null se manca la fotografia. [categorie] è null anche
/// per le fotografie di schema 1.
class PuntoMensile {
  const PuntoMensile({
    required this.mese,
    this.totale,
    this.liquiditaConSalvadanaio,
    this.investimenti,
    this.categorie,
  });

  final Mese mese;
  final int? totale;
  final int? liquiditaConSalvadanaio;
  final int? investimenti;
  final Map<CategoriaInvestimento, int>? categorie;
}

int _indice(Mese m) => m.anno * 12 + m.mese - 1;
Mese _daIndice(int i) => Mese(i ~/ 12, i % 12 + 1);

/// Un punto per ogni mese della finestra del [periodo], fino al mese di [oggi].
/// Con [PeriodoAndamento.tutto] e nessuna fotografia la serie è vuota.
List<PuntoMensile> serieMensile(
  List<FotografiaMensile> fotografie,
  PeriodoAndamento periodo,
  DateTime oggi,
) {
  final fine = _indice(Mese(oggi.year, oggi.month));
  final int inizio;
  switch (periodo) {
    case PeriodoAndamento.dodiciMesi:
      inizio = fine - 11;
    case PeriodoAndamento.treAnni:
      inizio = fine - 35;
    case PeriodoAndamento.annoInCorso:
      inizio = oggi.year * 12;
    case PeriodoAndamento.tutto:
      if (fotografie.isEmpty) return const [];
      inizio = fotografie
          .map((f) => _indice(f.mese))
          .reduce((a, b) => a < b ? a : b);
  }
  final perMese = {for (final f in fotografie) f.mese: f};
  return [
    for (var i = inizio; i <= fine; i++)
      _punto(_daIndice(i), perMese[_daIndice(i)]),
  ];
}

PuntoMensile _punto(Mese mese, FotografiaMensile? f) {
  if (f == null) return PuntoMensile(mese: mese);
  final s = f.situazione;
  return PuntoMensile(
    mese: mese,
    totale: s.totale,
    liquiditaConSalvadanaio:
        s.totaleGruppo(Gruppo.salvadanaio) + s.totaleGruppo(Gruppo.liquidita),
    investimenti: s.totaleGruppo(Gruppo.investimenti),
    categorie: f.haCategorie
        ? {
            for (final c in CategoriaInvestimento.values)
              c: s.totaleCategoria(c),
          }
        : null,
  );
}
