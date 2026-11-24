import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/voce_mapper.dart';
import 'package:personal_finance/domain/voce.dart';

void main() {
  test('CAT-003 categoria salvata e riletta per entrambe le tipologie', () {
    for (final v in [
      const Voce.semplice(
        id: 's',
        nome: 'Pensione',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.pianiAccumulo,
        saldoCentesimi: 4500,
      ),
      const Voce.conDettaglio(
        id: 'd',
        nome: 'Prestiti',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.p2pLanding,
        righe: [Riga(id: 'r', nome: 'Piattaforma', saldoCentesimi: 1200)],
      ),
    ]) {
      final documento = voceToMap(v, 4);
      final riletta = voceFromMap(v.id, documento);
      expect(riletta.categoria, v.categoria);
      expect(riletta.nome, v.nome);
      expect(riletta.saldoCentesimi, v.saldoCentesimi);
      expect(riletta.conDettaglio, v.conDettaglio);
      expect(documento['ordine'], 4);
    }
  });

  test(
    'CAT-019 dati precedenti senza categoria non sono classificati dal mapper',
    () {
      final v = voceFromMap('v20', {
        'nome': 'Pensionline',
        'gruppo': 'investimenti',
        'tipo': 'semplice',
        'ordine': 0,
        'saldoCentesimi': 1250,
      });
      expect(v.categoria, isNull);
      expect(v.saldoCentesimi, 1250);
      expect(voceToMap(v, 0).containsKey('categoria'), isFalse);
    },
  );

  test(
    'CAT-019 categoria su altro gruppo e valori di tipo errato rifiutati',
    () {
      for (final raw in ['crypto', 42, <String>[]]) {
        expect(
          () => voceFromMap('a', {
            'nome': 'BBVA',
            'gruppo': 'liquidita',
            'tipo': 'semplice',
            'ordine': 0,
            'saldoCentesimi': 100,
            'categoria': raw,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test('CAT-019 categoria sconosciuta non viene ignorata', () {
    expect(
      () => voceFromMap('v20', {
        'nome': 'Pensionline',
        'gruppo': 'investimenti',
        'tipo': 'semplice',
        'ordine': 0,
        'saldoCentesimi': 1250,
        'categoria': 'sconosciuta',
      }),
      throwsFormatException,
    );
  });

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
