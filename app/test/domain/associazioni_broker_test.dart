import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/associazioni_broker.dart';
import 'package:personal_finance/domain/voce.dart';

const _liq = Voce.semplice(
  id: 'liq',
  nome: 'Liquidità IBKR',
  gruppo: Gruppo.liquidita,
);
const _inv = Voce.semplice(
  id: 'inv',
  nome: 'IBKR',
  gruppo: Gruppo.investimenti,
);
const _det = Voce.conDettaglio(
  id: 'det',
  nome: 'Dettaglio',
  gruppo: Gruppo.investimenti,
);
const _voci = [_liq, _inv, _det];

AssociazioniConto _a(
  Map<String, AssociazioniConto> tutte,
  String conto,
  ComponenteBroker c,
  String voce,
) => associa(
  tutte: tutte,
  contoId: conto,
  componente: c,
  voceId: voce,
  voci: _voci,
);

void main() {
  test('BRO-015 liquidità e investimenti su voci distinte, con revisione', () {
    final a1 = _a({}, 'ibkr', ComponenteBroker.liquidita, 'liq');
    expect(a1.revisione, 1);
    expect(a1.liquidita, 'liq');
    expect(a1.investimenti, isNull);
    final a2 = _a({'ibkr': a1}, 'ibkr', ComponenteBroker.investimenti, 'inv');
    expect(a2.revisione, 2);
    expect(a2.liquidita, 'liq');
    expect(a2.investimenti, 'inv');
  });

  test(
    'BRO-016 rifiuta dettaglio, gruppo errato, duplicati e voce inesistente',
    () {
      final usata = {
        'degiro': const AssociazioniConto(revisione: 1, investimenti: 'inv'),
      };
      final casi = <(Map<String, AssociazioniConto>, ComponenteBroker, String)>[
        ({}, ComponenteBroker.investimenti, 'det'),
        ({}, ComponenteBroker.liquidita, 'inv'),
        ({}, ComponenteBroker.investimenti, 'liq'),
        (usata, ComponenteBroker.investimenti, 'inv'),
        ({}, ComponenteBroker.investimenti, 'sparita'),
      ];
      for (final (tutte, c, voce) in casi) {
        expect(
          () => _a(tutte, 'ibkr', c, voce),
          throwsA(isA<ValidazioneException>()),
          reason: voce,
        );
      }
    },
  );
}
