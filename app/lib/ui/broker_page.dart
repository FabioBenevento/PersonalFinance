import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/broker_providers.dart';
import '../data/voci_providers.dart';
import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';
import '../domain/voce.dart';
import 'app_theme.dart';
import 'broker_anteprima.dart';
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
      for (final c in rilevazione.conti) _Conto(c, rilevazione.id),
    ],
  );
}

class _Conto extends ConsumerWidget {
  const _Conto(this.conto, this.rilevazioneId);
  final ContoBroker conto;
  final String rilevazioneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
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
                'Stato del collegamento sconosciuto',
                style: const TextStyle(color: coloreNegativo),
              ),
            Text(
              conto.datiIl == null
                  ? 'Dati del: sconosciuta'
                  : 'Dati del ${_data(conto.datiIl!)}',
              style: const TextStyle(color: coloreSecondario),
            ),
            Text(
              conto.posizioniDatiIl == null
                  ? 'Posizioni del: sconosciuta'
                  : 'Posizioni del ${_data(conto.posizioniDatiIl!)}',
              style: const TextStyle(color: coloreSecondario),
            ),
            for (final c in ComponenteBroker.values) _Associazione(conto.id, c),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AnteprimaBroker(conto, rilevazioneId),
              ),
              child: const Text('Anteprima aggiornamento'),
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

class _Associazione extends ConsumerWidget {
  const _Associazione(this.contoId, this.componente);
  final String contoId;
  final ComponenteBroker componente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutte = ref.watch(associazioniBrokerProvider).value ?? const {};
    final voci = ref.watch(vociProvider).value ?? const <Voce>[];
    final id = tutte[contoId]?.destinazione(componente);
    final voce = voci.where((v) => v.id == id).firstOrNull;
    final nome = componente == ComponenteBroker.liquidita
        ? 'Liquidità'
        : 'Investimenti';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          id == null
              ? '$nome: non associata, nessuna proposta'
              : '$nome → ${voce?.nome ?? 'voce non più esistente'}',
          style: id == null ? const TextStyle(color: coloreSecondario) : null,
        ),
        TextButton(
          onPressed: () => _scegli(context, ref, tutte, voci),
          child: Text('Associa $nome'),
        ),
      ],
    );
  }

  Future<void> _scegli(
    BuildContext context,
    WidgetRef ref,
    Map<String, AssociazioniConto> tutte,
    List<Voce> voci,
  ) async {
    final gruppo = componente == ComponenteBroker.liquidita
        ? Gruppo.liquidita
        : Gruppo.investimenti;
    final usate = {
      for (final a in tutte.values)
        for (final c in ComponenteBroker.values) a.destinazione(c),
    };
    final candidate = [
      for (final v in voci)
        if (v.gruppo == gruppo && !v.conDettaglio && !usate.contains(v.id)) v,
    ];
    final messenger = ScaffoldMessenger.of(context);
    final scelta = await showDialog<Voce>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Scegli la voce'),
        children: [
          if (candidate.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Nessuna voce semplice disponibile'),
            ),
          for (final v in candidate)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, v),
              child: Text(v.nome),
            ),
        ],
      ),
    );
    if (scelta == null) return;
    try {
      final nuove = associa(
        tutte: tutte,
        contoId: contoId,
        componente: componente,
        voceId: scelta.id,
        voci: voci,
      );
      await ref
          .read(brokerRepositoryProvider)
          .salvaAssociazioni(contoId, nuove);
    } on ValidazioneException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
