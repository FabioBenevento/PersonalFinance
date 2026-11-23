import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/voce_mapper.dart';
import 'package:personal_finance/domain/voce.dart';

void main() {
  test('SIT-022 voce semplice: documento e ritorno', () {
    const v = Voce.semplice(
      id: 'a',
      nome: 'PayPal',
      gruppo: Gruppo.liquidita,
      saldoCentesimi: 1250,
    );
    expect(voceToMap(v, 3), {
      'nome': 'PayPal',
      'gruppo': 'liquidita',
      'tipo': 'semplice',
      'ordine': 3,
      'saldoCentesimi': 1250,
    });
    final r = voceFromMap('a', voceToMap(v, 3));
    expect(r.conDettaglio, isFalse);
    expect(r.nome, 'PayPal');
    expect(r.gruppo, Gruppo.liquidita);
    expect(r.saldoCentesimi, 1250);
  });

  test('SIT-022 voce con dettaglio: documento e ritorno', () {
    const v = Voce.conDettaglio(
      id: 'b',
      nome: 'Crypto',
      gruppo: Gruppo.investimenti,
      righe: [
        Riga(id: 'r0', nome: 'Binance', saldoCentesimi: 100),
        Riga(id: 'r1', nome: 'Conio', saldoCentesimi: 250),
      ],
    );
    expect(voceToMap(v, 0), {
      'nome': 'Crypto',
      'gruppo': 'investimenti',
      'tipo': 'dettaglio',
      'ordine': 0,
      'righe': [
        {'id': 'r0', 'nome': 'Binance', 'saldoCentesimi': 100},
        {'id': 'r1', 'nome': 'Conio', 'saldoCentesimi': 250},
      ],
    });
    final r = voceFromMap('b', voceToMap(v, 0));
    expect(r.conDettaglio, isTrue);
    expect(r.righe!.map((x) => x.nome), ['Binance', 'Conio']);
    expect(r.saldoCentesimi, 350);
  });
}
