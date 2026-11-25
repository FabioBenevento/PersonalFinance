import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/broker.dart';
import 'package:personal_finance/domain/proposta_broker.dart';

PosizioneBroker pos(
  String id, {
  String valuta = 'EUR',
  String? quantita = '1',
  String? prezzo,
  String? valore,
  bool? equivalente = false,
  TipoPosizione tipo = TipoPosizione.azione,
}) => PosizioneBroker(
  id: id,
  simbolo: id,
  descrizione: null,
  tipo: tipo,
  valuta: valuta,
  quantita: quantita,
  prezzo: prezzo,
  valore: valore,
  equivalenteLiquidita: equivalente,
);

ContoBroker conto({
  List<LiquiditaBroker> liquidita = const [
    LiquiditaBroker(valuta: 'EUR', importo: '0'),
  ],
  List<PosizioneBroker> posizioni = const [],
  StatoCollegamento stato = StatoCollegamento.attivo,
}) => ContoBroker(
  id: 'c',
  broker: 'B',
  nome: 'Conto',
  stato: stato,
  datiIl: null,
  liquidita: liquidita,
  posizioni: posizioni,
);

void main() {
  test('BRO-017 arrotondamento solo dopo l\'aggregazione', () {
    final p = proponi(
      conto(
        liquidita: [const LiquiditaBroker(valuta: 'USD', importo: '0.02')],
        posizioni: [
          pos('a', valuta: 'USD', valore: '0.01'),
          pos('b', valuta: 'USD', valore: '0.01'),
        ],
      ),
      cambi: {'USD': '0.5'},
    );
    expect(p.investimenti.centesimi, 1);
    expect(p.liquidita.centesimi, 1);
  });

  test('BRO-017 decimali esatti e metà per eccesso', () {
    final p = proponi(
      conto(
        posizioni: [
          pos('a', quantita: '1.123456789012345678', prezzo: '10.00'),
        ],
      ),
    );
    expect(p.investimenti.centesimi, 1123);
    final m = proponi(conto(posizioni: [pos('a', valore: '0.005')]));
    expect(m.investimenti.centesimi, 1);
  });

  test('BRO-017 più valute nella stessa componente', () {
    final p = proponi(
      conto(
        posizioni: [
          pos('a', valuta: 'USD', valore: '100'),
          pos('b', valuta: 'GBP', valore: '10'),
          pos('c', valore: '1'),
        ],
      ),
      cambi: {'USD': '0.9', 'GBP': '1.2'},
    );
    expect(p.investimenti.centesimi, 10300);
  });

  test('BRO-018 cambio mancante blocca solo la componente interessata', () {
    final p = proponi(
      conto(
        liquidita: [const LiquiditaBroker(valuta: 'EUR', importo: '100')],
        posizioni: [pos('a', valuta: 'USD', valore: '10')],
      ),
    );
    expect(p.investimenti.proponibile, isFalse);
    expect(p.investimenti.motivoBlocco, contains('USD'));
    expect(p.liquidita.centesimi, 10000);
  });

  test('BRO-018 dato mancante o conto non attivo blocca', () {
    final senzaValore = proponi(conto(posizioni: [pos('a', quantita: null)]));
    expect(senzaValore.investimenti.proponibile, isFalse);
    final senzaCash = proponi(
      conto(liquidita: [const LiquiditaBroker(valuta: 'EUR', importo: null)]),
    );
    expect(senzaCash.liquidita.proponibile, isFalse);
    final nonAttivo = proponi(conto(stato: StatoCollegamento.sconosciuto));
    expect(nonAttivo.liquidita.proponibile, isFalse);
    expect(nonAttivo.investimenti.proponibile, isFalse);
  });

  test('BRO-019 short con aggregato positivo, cash-equivalent escluso', () {
    final p = proponi(
      conto(
        liquidita: [const LiquiditaBroker(valuta: 'EUR', importo: '100')],
        posizioni: [
          pos('a', valore: '300'),
          pos('s', quantita: '-1', valore: '-50'),
          pos('mm', valore: '40', equivalente: true),
        ],
      ),
    );
    expect(p.liquidita.centesimi, 10000);
    expect(p.investimenti.centesimi, 25000);
  });

  test('BRO-020 netto negativo bloccato, non azzerato', () {
    final p = proponi(
      conto(
        posizioni: [
          pos('a', valore: '10'),
          pos('s', valore: '-60'),
        ],
      ),
    );
    expect(p.investimenti.proponibile, isFalse);
    expect(p.investimenti.motivoBlocco, contains('negativ'));
  });

  test('BRO-020 composizione ambigua o strumento sconosciuto bloccano', () {
    final ambigua = proponi(
      conto(posizioni: [pos('a', valore: '10', equivalente: null)]),
    );
    expect(ambigua.investimenti.proponibile, isFalse);
    final ignoto = proponi(
      conto(
        posizioni: [pos('a', valore: '10', tipo: TipoPosizione.sconosciuto)],
      ),
    );
    expect(ignoto.investimenti.proponibile, isFalse);
  });
}
