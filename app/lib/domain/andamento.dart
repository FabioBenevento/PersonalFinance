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

typedef Quota = ({int importo, int? percentuale});

/// Importi e percentuali (centesimi di punto) di gruppi e categorie; [categorie]
/// è null per le fotografie di schema 1.
class Composizione {
  const Composizione({required this.gruppi, this.categorie});

  final Map<Gruppo, Quota> gruppi;
  final Map<CategoriaInvestimento, Quota>? categorie;
}

Composizione composizione(FotografiaMensile f) {
  final s = f.situazione;
  return Composizione(
    gruppi: {
      for (final g in Gruppo.values)
        g: (importo: s.totaleGruppo(g), percentuale: s.percentualeGruppo(g)),
    },
    categorie: f.haCategorie
        ? {
            for (final c in CategoriaInvestimento.values)
              c: (
                importo: s.totaleCategoria(c),
                percentuale: s.percentualeCategoria(c),
              ),
          }
        : null,
  );
}

/// Confronto del Totale con [confronto]; [differenza] e [percentuale] sono null
/// se manca la fotografia ([mancante]); [percentuale] anche con base zero.
class Variazione {
  const Variazione({
    required this.confronto,
    this.differenza,
    this.percentuale,
  });

  final Mese confronto;
  final int? differenza;
  final int? percentuale;

  bool get mancante => differenza == null;
}

class VariazioniTotale {
  const VariazioniTotale({
    required this.precedente,
    required this.gennaio,
    required this.annoPrecedente,
  });

  final Variazione precedente;
  final Variazione gennaio;
  final Variazione annoPrecedente;
}

/// Variazioni del Totale dell'ultima fotografia; null senza fotografie.
VariazioniTotale? variazioni(List<FotografiaMensile> fotografie) {
  if (fotografie.isEmpty) return null;
  final ultima = fotografie.reduce(
    (a, b) => a.mese.compareTo(b.mese) >= 0 ? a : b,
  );
  final m = ultima.mese;
  final totale = ultima.situazione.totale;
  Variazione confronta(Mese c) {
    final base = fotografie
        .where((f) => f.mese == c)
        .map((f) => f.situazione.totale)
        .firstOrNull;
    if (base == null) return Variazione(confronto: c);
    final diff = totale - base;
    return Variazione(
      confronto: c,
      differenza: diff,
      percentuale: base == 0
          ? null
          : (diff.sign *
                ((diff.abs() * 20000 + base.abs()) ~/ (2 * base.abs())) *
                base.sign),
    );
  }

  return VariazioniTotale(
    precedente: confronta(_daIndice(_indice(m) - 1)),
    gennaio: confronta(Mese(m.anno, 1)),
    annoPrecedente: confronta(Mese(m.anno - 1, m.mese)),
  );
}
