import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/andamento.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';

FotografiaMensile foto(
  int anno,
  int mese, {
  int salvadanaio = 0,
  int liquidita = 0,
  List<int> inv = const [0, 0, 0, 0],
  int schema = schemaConCategorie,
}) => FotografiaMensile(
  mese: Mese(anno, mese),
  versioneSchema: schema,
  voci: [
    Voce.semplice(
      id: 's',
      nome: 'S',
      gruppo: Gruppo.salvadanaio,
      saldoCentesimi: salvadanaio,
    ),
    Voce.semplice(
      id: 'l',
      nome: 'L',
      gruppo: Gruppo.liquidita,
      saldoCentesimi: liquidita,
    ),
    for (final c in CategoriaInvestimento.values)
      Voce.semplice(
        id: 'i${c.index}',
        nome: 'I${c.index}',
        gruppo: Gruppo.investimenti,
        categoria: schema >= schemaConCategorie ? c : null,
        saldoCentesimi: inv[c.index],
      ),
  ],
);

void main() {
  final oggi = DateTime(2026, 11, 24);

  test('AND-004 valori per mese', () {
    final f = foto(
      2026,
      11,
      salvadanaio: 111807,
      liquidita: 6584678,
      inv: [5000000, 2000000, 2000000, 1452876],
    );
    final p = serieMensile([f], PeriodoAndamento.dodiciMesi, oggi).last;
    expect(p.mese, Mese(2026, 11));
    expect(p.totale, 17149361);
    expect(p.liquiditaConSalvadanaio, 6696485);
    expect(p.investimenti, 10452876);
  });

  test('AND-005 mesi senza fotografia', () {
    final fs = [foto(2023, 1), foto(2023, 3), foto(2023, 4)];
    final s = serieMensile(fs, PeriodoAndamento.tutto, DateTime(2023, 4, 10));
    expect(s.map((p) => p.mese), [
      Mese(2023, 1),
      Mese(2023, 2),
      Mese(2023, 3),
      Mese(2023, 4),
    ]);
    expect(s[1].totale, isNull);
    expect(s[1].liquiditaConSalvadanaio, isNull);
    expect(s[1].investimenti, isNull);
    expect(s[1].categorie, isNull);
    expect(s.where((p) => p.totale == 0).length, 3);
  });

  test('AND-006 finestre del periodo', () {
    final fs = [foto(2022, 1), foto(2026, 11)];
    List<Mese> m(PeriodoAndamento p) =>
        serieMensile(fs, p, oggi).map((x) => x.mese).toList();
    final d = m(PeriodoAndamento.dodiciMesi);
    expect([d.first, d.last, d.length], [Mese(2025, 12), Mese(2026, 11), 12]);
    final a = m(PeriodoAndamento.annoInCorso);
    expect([a.first, a.last], [Mese(2026, 1), Mese(2026, 11)]);
    final t = m(PeriodoAndamento.treAnni);
    expect([t.first, t.last, t.length], [Mese(2023, 12), Mese(2026, 11), 36]);
    final u = m(PeriodoAndamento.tutto);
    expect([u.first, u.last], [Mese(2022, 1), Mese(2026, 11)]);
  });

  test('AND-008 somma delle categorie', () {
    final f = foto(2026, 11, inv: [5000000, 2000000, 2000000, 1452876]);
    final p = serieMensile([f], PeriodoAndamento.annoInCorso, oggi).last;
    expect(p.categorie!.length, 4);
    expect(p.categorie![CategoriaInvestimento.crypto], 1452876);
    expect(p.categorie!.values.fold(0, (a, b) => a + b), 10452876);
  });

  test('AND-009 fotografia di schema 1', () {
    final f = foto(
      2026,
      11,
      liquidita: 1000,
      inv: [500, 0, 0, 0],
      schema: schemaPrecedente,
    );
    final p = serieMensile([f], PeriodoAndamento.annoInCorso, oggi).last;
    expect(p.categorie, isNull);
    expect(p.totale, 1500);
  });

  test(
    'composizione con importi e percentuali, categorie assenti in schema 1',
    () {
      final f = foto(
        2026,
        11,
        salvadanaio: 1000,
        liquidita: 3000,
        inv: [6000, 0, 0, 0],
      );
      final c = composizione(f);
      expect(c.gruppi[Gruppo.investimenti], (importo: 6000, percentuale: 6000));
      expect(c.gruppi[Gruppo.salvadanaio], (importo: 1000, percentuale: 1000));
      expect(c.categorie![CategoriaInvestimento.values[0]], (
        importo: 6000,
        percentuale: 10000,
      ));
      expect(
        composizione(foto(2026, 11, schema: schemaPrecedente)).categorie,
        isNull,
      );
    },
  );

  test('AND-013 variazioni calcolate', () {
    final v = variazioni([
      foto(2026, 11, liquidita: 17149361),
      foto(2026, 10, liquidita: 17000000),
      foto(2026, 1, liquidita: 16000000),
    ])!;
    expect(v.precedente.confronto, Mese(2026, 10));
    expect(v.precedente.differenza, 149361);
    expect(v.precedente.percentuale, 88);
    expect(v.gennaio.differenza, 1149361);
    expect(v.annoPrecedente.mancante, isTrue);
    expect(v.annoPrecedente.confronto, Mese(2025, 11));
    expect(v.annoPrecedente.differenza, isNull);
  });

  test('AND-014 mese di confronto mancante', () {
    final v = variazioni([
      foto(2026, 9, liquidita: 100),
      foto(2026, 6, liquidita: 50),
    ])!;
    expect(v.precedente.confronto, Mese(2026, 8));
    expect(v.precedente.mancante, isTrue);
    expect(v.precedente.differenza, isNull);
    expect(v.precedente.percentuale, isNull);
  });

  test('AND-015 gennaio come ultima fotografia', () {
    final v = variazioni([
      foto(2026, 1, liquidita: 100),
      foto(2025, 12, liquidita: 50),
    ])!;
    expect([v.gennaio.differenza, v.gennaio.percentuale], [0, 0]);
    expect(v.precedente.confronto, Mese(2025, 12));
    expect(v.precedente.differenza, 50);
  });

  test(
    'variazioni: base zero senza percentuale, negativa, nessuna fotografia',
    () {
      final v = variazioni([foto(2026, 2, liquidita: 100), foto(2026, 1)])!;
      expect([v.precedente.differenza, v.precedente.percentuale], [100, null]);
      final n = variazioni([
        foto(2026, 2, liquidita: 9900),
        foto(2026, 1, liquidita: 10000),
      ])!;
      expect([n.precedente.differenza, n.precedente.percentuale], [-100, -100]);
      expect(variazioni([]), isNull);
    },
  );

  test('cumulato per categoria, anche con categorie nascoste', () {
    final p = serieMensile(
      [
        foto(2026, 1, inv: [100, 200, 300, 400]),
      ],
      PeriodoAndamento.tutto,
      DateTime(2026, 1, 15),
    ).single;
    expect(CategoriaInvestimento.values.map(p.cumulato), [100, 300, 600, 1000]);
    expect(
      p.cumulato(
        CategoriaInvestimento.depositoTitoli,
        nascoste: {CategoriaInvestimento.p2pLanding},
      ),
      400,
    );
    final v1 = serieMensile(
      [foto(2026, 1, schema: 1)],
      PeriodoAndamento.tutto,
      DateTime(2026, 1, 15),
    ).single;
    expect(v1.cumulato(CategoriaInvestimento.crypto), isNull);
  });

  test('ultimaFotografia e finestra con fotografia dopo oggi', () {
    expect(ultimaFotografia([]), isNull);
    final f = [foto(2026, 3), foto(2026, 12), foto(2026, 5)];
    expect(ultimaFotografia(f)!.mese, Mese(2026, 12));
    final serie = serieMensile(
      [foto(2027, 2)],
      PeriodoAndamento.annoInCorso,
      DateTime(2026, 11, 24),
    );
    expect(serie.last.mese, Mese(2027, 2));
    expect(serie.first.mese, Mese(2026, 1));
    expect(
      serieMensile(
        [foto(2027, 2)],
        PeriodoAndamento.tutto,
        DateTime(2026, 11),
      ).single.mese,
      Mese(2027, 2),
    );
  });

  test('percentuale con segno proprio se la base è negativa', () {
    final v = variazioni([
      foto(2026, 2, liquidita: -500),
      foto(2026, 1, liquidita: -1000),
    ])!;
    expect([v.precedente.differenza, v.precedente.percentuale], [500, -5000]);
  });
}
