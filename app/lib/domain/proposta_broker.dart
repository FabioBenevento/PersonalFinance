import 'associazioni_broker.dart';
import 'broker.dart';

class ComponenteProposta {
  const ComponenteProposta.valida(int this.centesimi) : motivoBlocco = null;
  const ComponenteProposta.bloccata(String this.motivoBlocco)
    : centesimi = null;
  final int? centesimi;
  final String? motivoBlocco;
  bool get proponibile => centesimi != null;
}

class PropostaConto {
  const PropostaConto({required this.liquidita, required this.investimenti});
  final ComponenteProposta liquidita;
  final ComponenteProposta investimenti;

  ComponenteProposta di(ComponenteBroker c) =>
      c == ComponenteBroker.liquidita ? liquidita : investimenti;
}

/// Decimale esatto: [n] / 10^[scala].
class _Dec {
  const _Dec(this.n, this.scala);
  final BigInt n;
  final int scala;

  static final _re = RegExp(r'^([+-]?\d+)(?:\.(\d+))?$');

  static _Dec? leggi(String? t) {
    final m = t == null ? null : _re.firstMatch(t);
    if (m == null) return null;
    final f = m[2] ?? '';
    return _Dec(BigInt.parse('${m[1]}$f'), f.length);
  }

  _Dec operator *(_Dec o) => _Dec(n * o.n, scala + o.scala);

  _Dec operator +(_Dec o) {
    final s = scala > o.scala ? scala : o.scala;
    return _Dec(_a(s) + o._a(s), s);
  }

  BigInt _a(int s) => n * BigInt.from(10).pow(s - scala);

  /// Centesimi, metà per eccesso (il segno si controlla prima).
  int centesimi() {
    if (scala <= 2) return (n * BigInt.from(10).pow(2 - scala)).toInt();
    final d = BigInt.from(10).pow(scala - 2);
    return ((n * BigInt.two + d) ~/ (d * BigInt.two)).toInt();
  }
}

ComponenteProposta _somma(
  List<(String? valuta, _Dec? valore, String descrizione)> voci,
  Map<String, String> cambi,
) {
  var tot = _Dec(BigInt.zero, 0);
  for (final (valuta, valore, d) in voci) {
    if (valuta == null || valore == null) {
      return ComponenteProposta.bloccata('Dati mancanti: $d');
    }
    final cambio = valuta == 'EUR'
        ? _Dec(BigInt.one, 0)
        : _Dec.leggi(cambi[valuta]);
    if (cambio == null) {
      return ComponenteProposta.bloccata('Cambio $valuta mancante: $d');
    }
    tot = tot + valore * cambio;
  }
  if (tot.n.isNegative) {
    return const ComponenteProposta.bloccata('Saldo negativo');
  }
  return ComponenteProposta.valida(tot.centesimi());
}

/// Valore firmato della posizione nella sua valuta; null se non affidabile.
_Dec? _valore(PosizioneBroker p) {
  final v = _Dec.leggi(p.valore);
  if (v != null) return v;
  // Senza valore del fornitore le opzioni restano ambigue (prezzo per
  // azione o per contratto), quindi non si moltiplica mai per il moltiplicatore.
  if (p.tipo == TipoPosizione.opzione) return null;
  final q = _Dec.leggi(p.quantita);
  final pr = _Dec.leggi(p.prezzo);
  return q == null || pr == null ? null : q * pr;
}

/// Proposta dei saldi in euro di un conto; i [cambi] (EUR per 1 unità di
/// valuta) devono provenire dal fornitore e dalla stessa rilevazione.
PropostaConto proponi(
  ContoBroker conto, {
  Map<String, String> cambi = const {},
}) {
  if (!conto.proponibile) {
    const b = ComponenteProposta.bloccata('Collegamento non attivo');
    return const PropostaConto(liquidita: b, investimenti: b);
  }
  final liquidita = conto.liquidita.isEmpty
      ? const ComponenteProposta.bloccata('Liquidità non comunicata')
      : _somma([
          for (final l in conto.liquidita)
            (l.valuta, _Dec.leggi(l.importo), 'liquidità ${l.valuta}'),
        ], cambi);
  final voci = <(String?, _Dec?, String)>[];
  String? ambigua;
  for (final p in conto.posizioni) {
    if (p.equivalenteLiquidita == true) continue;
    if (p.equivalenteLiquidita == null || !p.valorizzabile) {
      ambigua = p.simbolo ?? p.id;
      break;
    }
    voci.add((p.valuta, _valore(p), p.simbolo ?? p.id));
  }
  final investimenti = ambigua != null
      ? ComponenteProposta.bloccata('Posizione non valorizzabile: $ambigua')
      : _somma(voci, cambi);
  return PropostaConto(liquidita: liquidita, investimenti: investimenti);
}
