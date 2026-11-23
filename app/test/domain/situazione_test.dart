import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/situazione.dart';
import 'package:personal_finance/domain/voce.dart';

Voce _v(String n, Gruppo g, int c) =>
    Voce.semplice(id: n, nome: n, gruppo: g, saldoCentesimi: c);

void main() {
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

  test('SIT-012 nome di voce non valido', () {
    final s = base();
    expect(() => s.aggiungiVoce(_v('', Gruppo.liquidita, 0)), rifiuta());
    expect(() => s.aggiungiVoce(_v('   ', Gruppo.liquidita, 0)), rifiuta());
    expect(
      () => s.aggiungiVoce(_v(' bbva ', Gruppo.investimenti, 0)),
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

  test('SIT-013 spostamento in un altro gruppo', () {
    final s = base();
    final r = s.spostaVoce('Fideuram', Gruppo.investimenti);
    expect(r.totaleGruppo(Gruppo.liquidita), 0);
    expect(r.totaleGruppo(Gruppo.investimenti), 15000);
    expect(r.voci.last.nome, 'Fideuram');
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
