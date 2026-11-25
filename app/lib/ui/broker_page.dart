import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/broker_providers.dart';
import '../domain/broker.dart';
import 'app_theme.dart';
import 'patrimonio_layout.dart';

class BrokerPage extends ConsumerWidget {
  const BrokerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text('PersonalFinance'),
      ),
    ),
    body: PatrimonioLayout(
      destinazione: Destinazione.broker,
      child: switch (ref.watch(rilevazioneBrokerProvider)) {
        AsyncData(:final value) when value == null => const Center(
          child: Text('Nessuna rilevazione disponibile'),
        ),
        AsyncData(:final value) => _Rilevazione(value!),
        AsyncError() => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(rilevazioneBrokerProvider),
            child: const Text('Impossibile leggere i dati dei broker'),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    ),
  );
}

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Le scadenze arrivano come `aaaa-mm-gg`; un formato diverso resta com'e.
String _scadenza(String s) {
  final d = DateTime.tryParse(s);
  return d == null ? s : _data(d);
}

class _Rilevazione extends StatelessWidget {
  const _Rilevazione(this.rilevazione);
  final RilevazioneBroker rilevazione;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Rilevazione del ${_data(rilevazione.lettaIl)}',
        style: const TextStyle(color: coloreSecondario),
      ),
      if (rilevazione.conti.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('Nessun conto nella rilevazione'),
        ),
      for (final c in rilevazione.conti) _Conto(c),
    ],
  );
}

class _Conto extends StatelessWidget {
  const _Conto(this.conto);
  final ContoBroker conto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: DocumentoPatrimonio(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              conto.nome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (conto.broker != null)
              Text(
                conto.broker!,
                style: const TextStyle(color: coloreSecondario),
              ),
            if (conto.stato != StatoCollegamento.attivo)
              Text(
                conto.stato == StatoCollegamento.daRinnovare
                    ? 'Collegamento da rinnovare'
                    : 'Stato del collegamento sconosciuto',
                style: const TextStyle(color: coloreNegativo),
              ),
            Text(
              conto.datiIl == null
                  ? 'Dati del: sconosciuta'
                  : 'Dati del ${_data(conto.datiIl!)}',
              style: const TextStyle(color: coloreSecondario),
            ),
            for (final l in conto.liquidita)
              Text('Liquidità ${l.importo ?? 'non disponibile'} ${l.valuta}'),
            if (conto.posizioni.isEmpty)
              const Text(
                'Nessuna posizione',
                style: TextStyle(color: coloreSecondario),
              ),
            for (final p in conto.posizioni) _Posizione(p),
          ],
        ),
      ),
    ),
  );
}

const _tipi = {
  TipoPosizione.azione: 'Azione',
  TipoPosizione.etf: 'ETF',
  TipoPosizione.opzione: 'Opzione',
  TipoPosizione.sconosciuto: 'Strumento sconosciuto',
};

class _Posizione extends StatelessWidget {
  const _Posizione(this.p);
  final PosizioneBroker p;

  @override
  Widget build(BuildContext context) {
    final o = p.opzione;
    final valuta = p.valuta ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(p.descrizione ?? p.simbolo ?? 'Posizione senza nome'),
        Text(
          '${_tipi[p.tipo]} · Quantità ${p.quantita ?? 'n.d.'} · '
          'Valore ${p.valore ?? 'n.d.'} $valuta',
          style: stileImportoSecondario,
        ),
        if (o != null)
          Text(
            [
              if (o.tipo != null) o.tipo == TipoOpzione.call ? 'Call' : 'Put',
              if (o.sottostanteSimbolo != null) 'su ${o.sottostanteSimbolo}',
              if (o.strike != null) 'strike ${o.strike}',
              if (o.scadenza != null) 'scadenza ${_scadenza(o.scadenza!)}',
              if (o.moltiplicatore != null)
                'moltiplicatore ${o.moltiplicatore}',
            ].join(' · '),
            style: stileImportoSecondario,
          ),
      ],
    );
  }
}
