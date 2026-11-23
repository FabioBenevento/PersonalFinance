import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/situazione.dart';
import 'package:personal_finance/domain/voce.dart';

Voce _v(String n, Gruppo g, int c) =>
    Voce.semplice(id: n, nome: n, gruppo: g, saldoCentesimi: c);

void main() {
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
    expect(s.percentualeVoce(bbva), '25,00%');
    expect(s.percentualeGruppo(Gruppo.liquidita), '25,00%');
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
    expect(s.percentualeVoce(a), '33,33%');
    expect(s.percentualeVoce(b), '12,50%');
  });

  test('SIT-018 base zero', () {
    final a = _v('a', Gruppo.salvadanaio, 0);
    final s = Situazione([a]);
    expect(s.percentualeVoce(a), '—');
    expect(s.percentualeGruppo(Gruppo.salvadanaio), '—');
  });
}
