import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/situazione.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/mese.dart';

Voce _v(String n, Gruppo g, int c) =>
    Voce.semplice(id: n, nome: n, gruppo: g, saldoCentesimi: c);

void main() {
  test(
    'CAT-006 categorie sul totale investimenti e dettaglio una sola volta',
    () {
      final s = Situazione([
        const Voce.semplice(
          id: 'pa',
          nome: 'Pensione',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.pianiAccumulo,
          saldoCentesimi: 10000,
        ),
        const Voce.conDettaglio(
          id: 'p',
          nome: 'Prestiti',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.p2pLanding,
          righe: [Riga(id: 'r', nome: 'Piattaforma', saldoCentesimi: 20000)],
        ),
        const Voce.semplice(
          id: 'd',
          nome: 'Titoli',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.depositoTitoli,
          saldoCentesimi: 40000,
        ),
        const Voce.semplice(
          id: 'c',
          nome: 'Criptovalute',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.crypto,
          saldoCentesimi: 10000,
        ),
        _v('conto', Gruppo.liquidita, 120000),
      ]);
      expect(CategoriaInvestimento.values.map(s.totaleCategoria), [
        10000,
        20000,
        40000,
        10000,
      ]);
      expect(CategoriaInvestimento.values.map(s.percentualeCategoria), [
        1250,
        2500,
        5000,
        1250,
      ]);
      expect(s.totaleGruppo(Gruppo.investimenti), 80000);
      final cambiata = s
          .modificaSaldoVoce('pa', 20000)
          .modificaSaldoRiga('p', 'r', 30000);
      expect(
        cambiata.totaleCategoria(CategoriaInvestimento.pianiAccumulo),
        20000,
      );
      expect(cambiata.totaleCategoria(CategoriaInvestimento.p2pLanding), 30000);
      expect(cambiata.totaleGruppo(Gruppo.investimenti), 100000);
      expect(
        cambiata.percentualeCategoria(CategoriaInvestimento.p2pLanding),
        3000,
      );
    },
  );

  test('CAT-006 arrotondamenti categoria come le altre percentuali', () {
    Situazione esempio(int resto) => Situazione([
      const Voce.semplice(
        id: 'p',
        nome: 'Pensione',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.pianiAccumulo,
        saldoCentesimi: 100,
      ),
      _v('altro', Gruppo.investimenti, resto),
    ]);
    expect(
      esempio(200).percentualeCategoria(CategoriaInvestimento.pianiAccumulo),
      3333,
    );
    expect(
      esempio(700).percentualeCategoria(CategoriaInvestimento.pianiAccumulo),
      1250,
    );
    final mezzo = Situazione([
      const Voce.semplice(
        id: 'p',
        nome: 'Pensione',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.pianiAccumulo,
        saldoCentesimi: 1,
      ),
      _v('altro', Gruppo.investimenti, 799),
    ]);
    expect(mezzo.percentualeCategoria(CategoriaInvestimento.pianiAccumulo), 13);
  });

  test('CAT-007 categorie vuote e base zero', () {
    const vuota = Situazione([]);
    expect(CategoriaInvestimento.values.map(vuota.totaleCategoria), [
      0,
      0,
      0,
      0,
    ]);
    expect(CategoriaInvestimento.values.map(vuota.percentualeCategoria), [
      null,
      null,
      null,
      null,
    ]);
    expect(vuota.classificazioneCompleta, isTrue);
    final s = Situazione([
      const Voce.semplice(
        id: 'p',
        nome: 'Pensione',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.pianiAccumulo,
        saldoCentesimi: 100,
      ),
    ]);
    expect(s.percentualeCategoria(CategoriaInvestimento.crypto), 0);
  });

  test(
    'CAT-008 voci da classificare anche a zero senza alterare il totale',
    () {
      final s = Situazione([
        const Voce.semplice(
          id: 'p',
          nome: 'Pensione',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.pianiAccumulo,
          saldoCentesimi: 10000,
        ),
        _v('ignota', Gruppo.investimenti, 5000),
        _v('zero', Gruppo.investimenti, 0),
        _v('conto', Gruppo.liquidita, 9000),
      ]);
      expect(s.vociDaClassificare.map((v) => v.id), ['ignota', 'zero']);
      expect(s.importoDaClassificare, 5000);
      expect(s.classificazioneCompleta, isFalse);
      expect(s.totaleGruppo(Gruppo.investimenti), 15000);
      expect(s.percentualeCategoria(CategoriaInvestimento.pianiAccumulo), 6667);
      final parziale = s.modificaCategoria(
        'ignota',
        CategoriaInvestimento.crypto,
      );
      expect(parziale.importoDaClassificare, 0);
      expect(parziale.classificazioneCompleta, isFalse);
      expect(
        parziale
            .modificaCategoria('zero', CategoriaInvestimento.crypto)
            .classificazioneCompleta,
        isTrue,
      );
    },
  );

  test(
    'CAT-003 categoria conservata da saldo, nome, righe e copia fotografica',
    () {
      const semplice = Voce.semplice(
        id: 's',
        nome: 'Pensione',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.pianiAccumulo,
        saldoCentesimi: 1200,
      );
      const dettaglio = Voce.conDettaglio(
        id: 'd',
        nome: 'Prestiti',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.p2pLanding,
        righe: [Riga(id: 'r', nome: 'Piattaforma', saldoCentesimi: 300)],
      );
      final s = Situazione([semplice, dettaglio])
          .rinominaVoce('s', 'Pensione nuova')
          .modificaSaldoVoce('s', 1500)
          .rinominaVoce('d', 'Prestiti nuovi')
          .rinominaRiga('d', 'r', 'Nuova piattaforma')
          .modificaSaldoRiga('d', 'r', 400);
      expect(s.voci.first.categoria, CategoriaInvestimento.pianiAccumulo);
      expect(s.voci.first.saldoCentesimi, 1500);
      expect(s.voci.last.categoria, CategoriaInvestimento.p2pLanding);
      expect(s.voci.last.righe!.single.nome, 'Nuova piattaforma');
      expect(s.voci.last.saldoCentesimi, 400);
      final copia = FotografiaMensile(mese: Mese(2026, 11), voci: s.voci);
      expect(copia.voci.map((v) => v.categoria), [
        CategoriaInvestimento.pianiAccumulo,
        CategoriaInvestimento.p2pLanding,
      ]);
    },
  );

  _operazioni();
  test('SIT-006 saldo come somma delle righe', () {
    const v = Voce.conDettaglio(
      id: 'm',
      nome: 'MatchBetting',
      gruppo: Gruppo.salvadanaio,
      righe: [
        Riga(id: '1', nome: 'Bwin', saldoCentesimi: 2000),
        Riga(id: '2', nome: 'Snai', saldoCentesimi: 40),
        Riga(id: '3', nome: 'Skybet', saldoCentesimi: 15),
      ],
    );
    expect(v.saldoCentesimi, 2055);
  });

  test('SIT-007 voce con dettaglio senza righe', () {
    const v = Voce.conDettaglio(id: 'm', nome: 'M', gruppo: Gruppo.salvadanaio);
    expect(v.saldoCentesimi, 0);
  });

  test('SIT-015 calcolo dei totali', () {
    final s = Situazione([
      _v('a', Gruppo.salvadanaio, 50000),
      _v('b', Gruppo.salvadanaio, 7207),
      _v('c', Gruppo.liquidita, 427669),
      _v('d', Gruppo.liquidita, 1),
      _v('e', Gruppo.investimenti, 100000),
    ]);
    expect(s.totaleGruppo(Gruppo.salvadanaio), 57207);
    expect(s.totaleGruppo(Gruppo.liquidita), 427670);
    expect(s.totaleGruppo(Gruppo.investimenti), 100000);
    expect(s.totale, 584877);
  });

  test('SIT-016 percentuali di voci e gruppi', () {
    final bbva = _v('BBVA', Gruppo.liquidita, 10000);
    final s = Situazione([
      bbva,
      _v('x', Gruppo.liquidita, 30000),
      _v('y', Gruppo.investimenti, 120000),
    ]);
    expect(s.totale, 160000);
    expect(s.percentualeVoce(bbva), 2500);
    expect(s.percentualeGruppo(Gruppo.liquidita), 2500);
  });

  test('SIT-017 arrotondamento', () {
    final a = _v('a', Gruppo.salvadanaio, 100);
    final b = _v('b', Gruppo.liquidita, 100);
    final s = Situazione([
      a,
      _v('a2', Gruppo.salvadanaio, 200),
      b,
      _v('b2', Gruppo.liquidita, 700),
    ]);
    expect(s.percentualeVoce(a), 3333);
    expect(s.percentualeVoce(b), 1250);

    // 1/800 = 0,125%: metà esatta, arrotondata per eccesso
    final c = _v('c', Gruppo.investimenti, 1);
    final s2 = Situazione([c, _v('c2', Gruppo.investimenti, 799)]);
    expect(s2.percentualeVoce(c), 13);
  });

  test('SIT-018 base zero', () {
    final a = _v('a', Gruppo.salvadanaio, 0);
    final s = Situazione([a]);
    expect(s.percentualeVoce(a), isNull);
    expect(s.percentualeGruppo(Gruppo.salvadanaio), isNull);
  });
}

void _operazioni() {
  Situazione base() => Situazione([
    _v('BBVA', Gruppo.liquidita, 0),
    _v('Fideuram', Gruppo.liquidita, 10000),
    _v('ETF', Gruppo.investimenti, 5000),
  ]);
  Situazione conRighe() => const Situazione([
    Voce.conDettaglio(
      id: 'm',
      nome: 'M',
      gruppo: Gruppo.salvadanaio,
      righe: [Riga(id: '1', nome: 'Bwin', saldoCentesimi: 100)],
    ),
  ]);
  Matcher rifiuta() => throwsA(isA<ValidazioneException>());

  test(
    'CAT-002 creazione investimenti richiede categoria per entrambi i tipi',
    () {
      final s = base();
      for (final v in [
        const Voce.semplice(
          id: 'n',
          nome: 'Nuova',
          gruppo: Gruppo.investimenti,
        ),
        const Voce.conDettaglio(
          id: 'n',
          nome: 'Nuova',
          gruppo: Gruppo.investimenti,
        ),
      ]) {
        expect(() => s.aggiungiVoce(v), rifiuta());
        final r = s.aggiungiVoce(
          v.copyWith(categoria: CategoriaInvestimento.crypto),
        );
        expect(r.voci.last.id, 'n');
        expect(r.voci.last.categoria, CategoriaInvestimento.crypto);
        expect(r.voci.last.saldoCentesimi, 0);
        expect(r.voci.last.conDettaglio, v.conDettaglio);
      }
      expect(s.voci.length, 3);
    },
  );

  test('SIT-012 nome di voce non valido', () {
    final s = base();
    expect(() => s.aggiungiVoce(_v('', Gruppo.liquidita, 0)), rifiuta());
    expect(() => s.aggiungiVoce(_v('   ', Gruppo.liquidita, 0)), rifiuta());
    expect(
      () => s.aggiungiVoce(
        _v(
          ' bbva ',
          Gruppo.investimenti,
          0,
        ).copyWith(categoria: CategoriaInvestimento.crypto),
      ),
      rifiuta(),
    );
    expect(() => s.rinominaVoce('Fideuram', ' bbva '), rifiuta());
    expect(() => s.rinominaVoce('Fideuram', ' '), rifiuta());
    expect(s.voci.map((v) => v.nome), ['BBVA', 'Fideuram', 'ETF']);
  });

  test('SIT-012 aggiunta in fondo al gruppo e rinomina', () {
    final s = base().aggiungiVoce(_v(' Conto Arancio ', Gruppo.liquidita, 0));
    expect(s.voci.map((v) => v.nome), [
      'BBVA',
      'Fideuram',
      'Conto Arancio',
      'ETF',
    ]);
    expect(s.rinominaVoce('BBVA', 'bbva').voci.first.nome, 'bbva');
  });

  test('CAT-004 ingresso senza scelta rifiutato senza modifiche', () {
    final s = conRighe();
    expect(() => s.spostaVoce('m', Gruppo.investimenti), rifiuta());
    expect(s.voci.single.gruppo, Gruppo.salvadanaio);
    expect(s.voci.single.saldoCentesimi, 100);
  });

  test('CAT-005 uscita rimuove categoria e rientro richiede nuova scelta', () {
    final s = conRighe().spostaVoce(
      'm',
      Gruppo.investimenti,
      categoria: CategoriaInvestimento.p2pLanding,
    );
    final uscita = s.spostaVoce('m', Gruppo.liquidita);
    expect(uscita.voci.single.categoria, isNull);
    expect(uscita.voci.single.id, 'm');
    expect(uscita.voci.single.righe!.single.id, '1');
    expect(uscita.voci.single.righe!.single.nome, 'Bwin');
    expect(uscita.voci.single.saldoCentesimi, 100);
    expect(() => uscita.spostaVoce('m', Gruppo.investimenti), rifiuta());
    final rientro = uscita.spostaVoce(
      'm',
      Gruppo.investimenti,
      categoria: CategoriaInvestimento.crypto,
    );
    expect(rientro.voci.single.categoria, CategoriaInvestimento.crypto);
    expect(rientro.voci.single.saldoCentesimi, 100);
  });

  test('SIT-013 spostamento in un altro gruppo', () {
    final s = base();
    final r = s.spostaVoce(
      'Fideuram',
      Gruppo.investimenti,
      categoria: CategoriaInvestimento.depositoTitoli,
    );
    expect(r.totaleGruppo(Gruppo.liquidita), 0);
    expect(r.totaleGruppo(Gruppo.investimenti), 15000);
    expect(r.voci.last.nome, 'Fideuram');
    expect(r.voci.last.categoria, CategoriaInvestimento.depositoTitoli);
    expect(r.totale, s.totale);
  });

  test('SIT-010 nomi delle righe validi', () {
    final s = conRighe();
    const r = Riga(id: '2', nome: 'Snai');
    expect(
      () => s.aggiungiRiga('m', const Riga(id: '2', nome: ' ')),
      rifiuta(),
    );
    expect(
      () => s.aggiungiRiga('m', const Riga(id: '2', nome: 'BWIN')),
      rifiuta(),
    );
    expect(() => s.rinominaRiga('m', '1', ''), rifiuta());
    final t = s.aggiungiRiga('m', r);
    expect(() => t.rinominaRiga('m', '2', ' bwin'), rifiuta());
    expect(
      t.rinominaRiga('m', '2', 'Skybet').voci.single.righe!.last.nome,
      'Skybet',
    );
  });

  test('SIT-010 modifica ed eliminazione delle righe', () {
    final s = conRighe().aggiungiRiga('m', const Riga(id: '2', nome: 'Snai'));
    final m = s.modificaSaldoRiga('m', '2', 40);
    expect(m.voci.single.saldoCentesimi, 140);
    final e = m.eliminaRiga('m', '1');
    expect(e.voci.single.saldoCentesimi, 40);
    expect(e.voci.single.righe!.length, 1);
  });

  test('SIT-005 modifica del saldo di una voce semplice dal dominio', () {
    final s = base().modificaSaldoVoce('BBVA', 4242);
    expect(s.voci.firstWhere((v) => v.id == 'BBVA').saldoCentesimi, 4242);
    expect(s.totale, 4242 + 10000 + 5000);
  });
}
