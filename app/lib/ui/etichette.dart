import '../domain/mese.dart';
import '../domain/voce.dart';

const nomiGruppo = {
  Gruppo.salvadanaio: 'Salvadanaio',
  Gruppo.liquidita: 'Liquidità',
  Gruppo.investimenti: 'Investimenti',
};

const nomiCategoria = {
  CategoriaInvestimento.pianiAccumulo: 'Piani accumulo',
  CategoriaInvestimento.p2pLanding: 'P2P Landing',
  CategoriaInvestimento.depositoTitoli: 'Deposito Titoli',
  CategoriaInvestimento.crypto: 'Crypto',
};

const nomiMesi = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

String nomeMese(Mese mese) => '${nomiMesi[mese.mese - 1]} ${mese.anno}';

/// Importo in euro in forma compatta per gli assi, es. `€ 120k`.
String scriviCompatto(double euro) {
  String n(double v) {
    final t = v.toStringAsFixed(1);
    return t.endsWith('.0')
        ? t.substring(0, t.length - 2)
        : t.replaceAll('.', ',');
  }

  final a = euro.abs();
  final s = euro < 0 ? '-' : '';
  if (a >= 1e6) return '$s€ ${n(a / 1e6)}M';
  if (a >= 1e3) return '$s€ ${n(a / 1e3)}k';
  return '$s€ ${a.round()}';
}
