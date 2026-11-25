/// Rilevazione di conti broker, indipendente dal fornitore che l'ha prodotta.
/// Quantita, prezzi e strike restano stringhe decimali esatte; null significa
/// dato assente, mai zero.
enum TipoPosizione { azione, etf, opzione, sconosciuto }

enum StatoCollegamento { attivo, daRinnovare, sconosciuto }

enum TipoOpzione { call, put }

class OpzioneBroker {
  const OpzioneBroker({
    required this.sottostanteSimbolo,
    required this.tipo,
    required this.strike,
    required this.scadenza,
    required this.moltiplicatore,
  });
  final String? sottostanteSimbolo;
  final TipoOpzione? tipo;
  final String? strike;
  final String? scadenza;
  final String? moltiplicatore;
}

class PosizioneBroker {
  const PosizioneBroker({
    required this.id,
    required this.simbolo,
    required this.descrizione,
    required this.tipo,
    required this.valuta,
    required this.quantita,
    required this.prezzo,
    required this.valore,
    this.equivalenteLiquidita,
    this.opzione,
  });
  final String id;
  final String? simbolo;
  final String? descrizione;
  final TipoPosizione tipo;
  final String? valuta;
  final String? quantita;
  final String? prezzo;
  final String? valore;

  /// true: gia incluso nella liquidita; null: il fornitore non lo dice.
  final bool? equivalenteLiquidita;
  final OpzioneBroker? opzione;

  /// Una posizione con tipo sconosciuto o dati mancanti resta consultabile ma
  /// non permette una valorizzazione affidabile.
  bool get valorizzabile =>
      tipo != TipoPosizione.sconosciuto &&
      valuta != null &&
      quantita != null &&
      (valore != null || prezzo != null);
}

class LiquiditaBroker {
  const LiquiditaBroker({required this.valuta, required this.importo});
  final String valuta;
  final String? importo;
}

class ContoBroker {
  const ContoBroker({
    required this.id,
    required this.broker,
    required this.nome,
    required this.stato,
    required this.datiIl,
    required this.liquidita,
    required this.posizioni,
  });
  final String id;
  final String? broker;
  final String nome;
  final StatoCollegamento stato;

  /// Data dei dati comunicata dal fornitore; null se sconosciuta. Non e mai
  /// sostituita dalla data della lettura.
  final DateTime? datiIl;
  final List<LiquiditaBroker> liquidita;
  final List<PosizioneBroker> posizioni;

  /// Solo un collegamento noto come attivo puo generare proposte.
  bool get proponibile => stato == StatoCollegamento.attivo;
}

class RilevazioneBroker {
  const RilevazioneBroker({
    required this.lettaIl,
    required this.conti,
    this.id = '',
  });

  /// Id della generazione attiva letta; vuoto nelle fixture senza origine.
  final String id;
  final DateTime lettaIl;
  final List<ContoBroker> conti;
}
