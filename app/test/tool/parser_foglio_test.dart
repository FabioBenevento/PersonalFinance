import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/voce.dart';

import '../../tool/import_storico/parser_foglio.dart';

final tabella = TabellaNomi.fromJson({
  'voci': {
    'Portafoglio': {'id': 'v0', 'nome': 'Contanti', 'gruppo': 'salvadanaio'},
    'MatchBetting': {
      'id': 'v3',
      'nome': 'MatchBetting',
      'gruppo': 'salvadanaio',
    },
    'Wibida': {'id': 'v30', 'nome': 'Widiba', 'gruppo': 'liquidita'},
    'Widiba': {'id': 'v30', 'nome': 'Widiba', 'gruppo': 'liquidita'},
    'Hype': {'id': 's-hype', 'nome': 'Hype', 'gruppo': 'liquidita'},
    'Crowdfounding': {
      'id': 'v23',
      'nome': 'Crowdfounding',
      'gruppo': 'investimenti',
      'categoria': 'p2pLanding',
    },
    'OvalMoney': {
      'id': 's-oval',
      'nome': 'OvalMoney',
      'gruppo': 'investimenti',
      'categoria': 'pianiAccumulo',
    },
    'Senza': {'id': 's-senza', 'nome': 'Senza', 'gruppo': 'investimenti'},
  },
  'totali': ['Totale Liquidità', 'Totale Investimenti', 'Totale'],
  'ignorare': ['TFR', 'Base Imponibile'],
});

List<List<Object?>> foglio2022() => [
  ['Portafoglio', '€ 50,00', '1%'],
  ['MatchBetting', '€ 199,07', '2%'],
  [],
  ['Wibida', '€ 1.000,00', ''],
  ['Hype', '€ 20,00', ''],
  ['Totale Liquidità', '€ 1.020,00', ''],
  ['Crowdfounding', '€ 300,00', ''],
  ['OvalMoney', '€ 10,00', ''],
  ['TFR lordo', '€ 9.999,00', ''],
  ['Totale con TFR', '€ 99.999,00', ''],
  ['Totale', '€ 1.579,07', ''],
];

void main() {
  test('IMP-007 e IMP-013 voci passate e voci con dettaglio come semplici', () {
    final f = parseFoglio(
      celle: foglio2022(),
      anno: 2022,
      mese: 1,
      tabella: tabella,
    );
    expect(f.voci.map((v) => v.id), [
      'v0',
      'v3',
      'v30',
      's-hype',
      'v23',
      's-oval',
    ]);
    final mb = f.voci[1];
    expect(mb.gruppo, Gruppo.salvadanaio);
    expect(mb.conDettaglio, isFalse);
    expect(mb.saldoCentesimi, 19907);
    expect(f.voci[3].gruppo, Gruppo.liquidita);
    expect(f.voci[3].saldoCentesimi, 2000);
    expect(f.totali, {'Totale Liquidità': 102000, 'Totale': 157907});
  });

  test('IMP-005 nomi diversi della stessa voce', () {
    Voce widiba(String etichetta) => parseFoglio(
      celle: [
        [etichetta, '€ 5,00'],
      ],
      anno: 2022,
      mese: 2,
      tabella: tabella,
    ).voci.single;
    expect(widiba('Wibida').id, widiba('Widiba').id);
    expect(widiba('Wibida').nome, 'Widiba');
    final c = parseFoglio(
      celle: [
        ['Portafoglio', '€ 5,00'],
      ],
      anno: 2022,
      mese: 2,
      tabella: tabella,
    );
    expect(c.voci.single.nome, 'Contanti');
  });

  test('IMP-006 etichetta sconosciuta ferma con voce, anno e mese', () {
    expect(
      () => parseFoglio(
        celle: [
          ['Hype2', '€ 1,00'],
        ],
        anno: 2026,
        mese: 3,
        tabella: tabella,
      ),
      throwsA(
        isA<PreparazioneException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Hype2'), contains('2026'), contains('03')),
        ),
      ),
    );
  });

  test('IMP-006 importo illeggibile ferma con voce, anno e mese', () {
    expect(
      () => parseFoglio(
        celle: [
          ['Hype', 'n.d.'],
        ],
        anno: 2026,
        mese: 11,
        tabella: tabella,
      ),
      throwsA(
        isA<PreparazioneException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Hype'), contains('2026'), contains('11')),
        ),
      ),
    );
  });

  test('IMP-008 categoria dalla tabella', () {
    final f = parseFoglio(
      celle: foglio2022(),
      anno: 2022,
      mese: 1,
      tabella: tabella,
    );
    expect(f.voci[4].categoria, CategoriaInvestimento.p2pLanding);
    expect(f.voci[5].categoria, CategoriaInvestimento.pianiAccumulo);
  });

  test('IMP-009 investimento senza categoria ferma con la voce', () {
    expect(
      () => parseFoglio(
        celle: [
          ['Senza', '€ 1,00'],
        ],
        anno: 2026,
        mese: 1,
        tabella: tabella,
      ),
      throwsA(
        isA<PreparazioneException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Senza'), contains('2026')),
        ),
      ),
    );
  });

  test('IMP-006 foglio 2026 con righe ignorate e totale illeggibile', () {
    final f = parseFoglio(
      celle: [
        ['Hype', '€ 7,00', '', 'Base Imponibile'],
        ['TFR netto', '€ 5,00'],
        ['Totale Investimenti', '€ 0,00'],
      ],
      anno: 2026,
      mese: 10,
      tabella: tabella,
    );
    expect(f.voci.single.id, 's-hype');
    expect(f.totali, {'Totale Investimenti': 0});
    expect(
      () => parseFoglio(
        celle: [
          ['Totale', 'x'],
        ],
        anno: 2026,
        mese: 10,
        tabella: tabella,
      ),
      throwsA(isA<PreparazioneException>()),
    );
  });
}
