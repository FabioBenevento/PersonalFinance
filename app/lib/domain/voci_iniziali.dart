import 'voce.dart';

const categorieInizialiInvestimenti = {
  'v14': CategoriaInvestimento.p2pLanding,
  'v15': CategoriaInvestimento.depositoTitoli,
  'v16': CategoriaInvestimento.depositoTitoli,
  'v17': CategoriaInvestimento.depositoTitoli,
  'v18': CategoriaInvestimento.depositoTitoli,
  'v19': CategoriaInvestimento.depositoTitoli,
  'v20': CategoriaInvestimento.pianiAccumulo,
  'v21': CategoriaInvestimento.pianiAccumulo,
  'v22': CategoriaInvestimento.crypto,
  'v23': CategoriaInvestimento.p2pLanding,
};

Voce _voceSemplice(int i, String nome, Gruppo g) => Voce.semplice(
  id: 'v$i',
  nome: nome,
  gruppo: g,
  categoria: categorieInizialiInvestimenti['v$i'],
);

Voce _voceConDettaglio(int i, String nome, Gruppo g, List<String> righe) =>
    Voce.conDettaglio(
      id: 'v$i',
      nome: nome,
      gruppo: g,
      categoria: categorieInizialiInvestimenti['v$i'],
      righe: [
        for (var j = 0; j < righe.length; j++)
          Riga(id: 'v$i-r$j', nome: righe[j]),
      ],
    );

/// Voci della Situazione Patrimoniale del 22/11/2026, nell'ordine dei fogli.
final List<Voce> vociIniziali = List.unmodifiable([
  _voceSemplice(0, 'Contanti', Gruppo.salvadanaio),
  _voceSemplice(1, 'PayPal', Gruppo.salvadanaio),
  _voceSemplice(2, 'Satispay', Gruppo.salvadanaio),
  _voceConDettaglio(3, 'MatchBetting', Gruppo.salvadanaio, [
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
    _voceSemplice(4 + i, n, Gruppo.liquidita),
  _voceConDettaglio(14, 'P2PLanding', Gruppo.investimenti, [
    'Bondora',
    'Mintos',
    'Evenfi',
    'Recrowd',
  ]),
  _voceSemplice(15, 'Deposito Titoli – Scalable Capital', Gruppo.investimenti),
  _voceSemplice(16, 'Deposito Titoli – TradeRepublic', Gruppo.investimenti),
  _voceSemplice(17, 'Deposito Titoli – Directa', Gruppo.investimenti),
  _voceSemplice(18, 'Deposito Titoli – DeGiro', Gruppo.investimenti),
  _voceSemplice(19, 'Interactive Brokers', Gruppo.investimenti),
  _voceSemplice(20, 'Pensionline', Gruppo.investimenti),
  _voceSemplice(21, 'Piano Piano', Gruppo.investimenti),
  _voceConDettaglio(22, 'Crypto', Gruppo.investimenti, [
    'Binance',
    'Conio',
    'YoungPlatform',
    'Exodus',
  ]),
  _voceSemplice(23, 'Crowdfounding', Gruppo.investimenti),
]);
