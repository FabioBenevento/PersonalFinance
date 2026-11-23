import 'voce.dart';

Voce _s(int i, String nome, Gruppo g) =>
    Voce.semplice(id: 'v$i', nome: nome, gruppo: g);

Voce _d(int i, String nome, Gruppo g, List<String> righe) => Voce.conDettaglio(
  id: 'v$i',
  nome: nome,
  gruppo: g,
  righe: [
    for (var j = 0; j < righe.length; j++) Riga(id: 'v$i-r$j', nome: righe[j]),
  ],
);

/// Voci della Situazione Patrimoniale del 22/11/2026, nell'ordine dei fogli.
final List<Voce> vociIniziali = List.unmodifiable([
  _s(0, 'Contanti', Gruppo.salvadanaio),
  _s(1, 'PayPal', Gruppo.salvadanaio),
  _s(2, 'Satispay', Gruppo.salvadanaio),
  _d(3, 'MatchBetting', Gruppo.salvadanaio, [
    'Betfair',
    'Sisal',
    'Bwin',
    'Planet365',
    'Bet365',
    'Snai',
    'GoldBet',
    'Skybet',
    'EuroBet',
    'SportPesa',
    'Better Lottomatica',
    'BetFlag',
    'GiocoDigitale',
    'StanleyBet',
    'Betclic',
    '888sport',
    'Betaland',
    'Unibet',
  ]),
  for (final (i, n) in [
    'Youbanking',
    'BBVA',
    'Degiro',
    'N26',
    'Revolut',
    'Trade Republic',
    'Scalable Capital',
    'Directa',
    'Fideuram',
    'Mediolanum',
  ].indexed)
    _s(4 + i, n, Gruppo.liquidita),
  _d(14, 'P2PLanding', Gruppo.investimenti, [
    'Bondora',
    'Mintos',
    'Evenfi',
    'Recrowd',
  ]),
  _s(15, 'Deposito Titoli – Scalable Capital', Gruppo.investimenti),
  _s(16, 'Deposito Titoli – TradeRepublic', Gruppo.investimenti),
  _s(17, 'Deposito Titoli – Directa', Gruppo.investimenti),
  _s(18, 'Deposito Titoli – DeGiro', Gruppo.investimenti),
  _s(19, 'Interactive Brokers', Gruppo.investimenti),
  _s(20, 'Pensionline', Gruppo.investimenti),
  _s(21, 'Piano Piano', Gruppo.investimenti),
  _d(22, 'Crypto', Gruppo.investimenti, [
    'Binance',
    'Conio',
    'YoungPlatform',
    'Exodus',
  ]),
  _s(23, 'Crowdfounding', Gruppo.investimenti),
]);
