import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';

const schemaBrokerSupportato = 1;

/// Converte la rilevazione normalizzata annidata (stesso formato delle
/// fixture condivise con il comando locale).
RilevazioneBroker rilevazioneFromJson(
  Map<String, dynamic> json, {
  String id = '',
}) {
  if (json['schemaVersion'] != schemaBrokerSupportato) {
    throw const FormatException('Versione rilevazione broker non supportata');
  }
  return RilevazioneBroker(
    id: id,
    lettaIl: DateTime.parse(json['lettaIl'] as String),
    conti: [
      for (final c in json['conti'] as List)
        _conto(Map<String, dynamic>.from(c as Map)),
    ],
  );
}

/// Ricompone la generazione attiva dai documenti Firestore. Una generazione
/// non marcata completa o con manifest diverso e uno staging abbandonato: non
/// e mai un elenco vuoto valido.
RilevazioneBroker rilevazioneDaDocumenti(
  Map<String, dynamic> testata,
  List<Map<String, dynamic>> conti,
  List<Map<String, dynamic>> posizioni, {
  String id = '',
}) {
  final manifest = testata['manifest'];
  if (testata['completa'] != true ||
      manifest is! Map ||
      manifest['conti'] != conti.length ||
      manifest['posizioni'] != posizioni.length) {
    throw const FormatException('Rilevazione broker incompleta');
  }
  return rilevazioneFromJson(id: id, {
    ...testata,
    'conti': [
      for (final c in conti)
        {
          ...c,
          'posizioni': [
            for (final p in posizioni)
              if (p['contoId'] == c['id']) p,
          ],
        },
    ],
  });
}

ContoBroker _conto(Map<String, dynamic> c) => ContoBroker(
  id: c['id'] as String,
  broker: c['broker'] as String?,
  nome: (c['nome'] as String?) ?? 'Nome non disponibile',
  stato: switch (c['statoCollegamento']) {
    'attivo' => StatoCollegamento.attivo,
    _ => StatoCollegamento.sconosciuto,
  },
  datiIl: _data(c['datiIl']),
  posizioniDatiIl: _data(c['posizioniDatiIl']),
  liquidita: [
    for (final l in (c['liquidita'] as List? ?? const []))
      LiquiditaBroker(
        valuta: (l as Map)['valuta'] as String,
        importo: l['importo'] as String?,
      ),
  ],
  posizioni: [
    for (final p in (c['posizioni'] as List? ?? const []))
      _posizione(Map<String, dynamic>.from(p as Map)),
  ],
);

DateTime? _data(Object? v) => v is String ? DateTime.tryParse(v) : null;

PosizioneBroker _posizione(Map<String, dynamic> p) {
  final o = p['opzione'];
  return PosizioneBroker(
    id: p['id'] as String,
    simbolo: p['simbolo'] as String?,
    descrizione: p['descrizione'] as String?,
    tipo: switch (p['tipo']) {
      'azione' => TipoPosizione.azione,
      'etf' => TipoPosizione.etf,
      'opzione' => TipoPosizione.opzione,
      _ => TipoPosizione.sconosciuto,
    },
    valuta: p['valuta'] as String?,
    quantita: p['quantita'] as String?,
    prezzo: p['prezzo'] as String?,
    valore: p['valore'] as String?,
    equivalenteLiquidita: p['equivalenteLiquidita'] as bool?,
    opzione: o is Map
        ? OpzioneBroker(
            sottostanteSimbolo:
                (o['sottostante'] as Map?)?['simbolo'] as String?,
            tipo: switch (o['tipo']) {
              'call' => TipoOpzione.call,
              'put' => TipoOpzione.put,
              _ => null,
            },
            strike: o['strike'] as String?,
            scadenza: o['scadenza'] as String?,
            moltiplicatore: o['moltiplicatore'] as String?,
          )
        : null,
  );
}

AssociazioniConto associazioniFromMap(Map<String, dynamic> m) =>
    AssociazioniConto(
      revisione: m['revisione'] as int,
      liquidita: m['liquidita'] as String?,
      investimenti: m['investimenti'] as String?,
    );

Map<String, dynamic> associazioniToMap(AssociazioniConto a) => {
  'revisione': a.revisione,
  if (a.liquidita != null) 'liquidita': a.liquidita,
  if (a.investimenti != null) 'investimenti': a.investimenti,
};
