import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/broker_providers.dart';
import '../data/voci_providers.dart';
import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';
import '../domain/importo.dart';
import '../domain/proposta_broker.dart';
import '../domain/voce.dart';
import 'app_theme.dart';

String _giorno(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _differenza(int c) => '${c < 0 ? '-' : '+'}${scriviImporto(c.abs())}';

/// Anteprima del confronto fra saldi attuali e proposti di un conto: non
/// scrive nulla; la conferma dei saldi selezionati arriva con il task 4.1.
class AnteprimaBroker extends ConsumerStatefulWidget {
  const AnteprimaBroker(this.conto, {super.key});
  final ContoBroker conto;

  @override
  ConsumerState<AnteprimaBroker> createState() => _AnteprimaBrokerState();
}

class _AnteprimaBrokerState extends ConsumerState<AnteprimaBroker> {
  final _selezionate = <ComponenteBroker>{};

  @override
  Widget build(BuildContext context) {
    final conto = widget.conto;
    final assoc =
        ref.watch(associazioniBrokerProvider).value?[conto.id] ??
        const AssociazioniConto();
    final voci = ref.watch(vociProvider).value ?? const <Voce>[];
    final proposta = proponi(conto);
    return AlertDialog(
      title: Text('Anteprima · ${conto.nome}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              conto.datiIl == null
                  ? 'Dati del: sconosciuta'
                  : 'Dati del ${_giorno(conto.datiIl!)}',
              style: const TextStyle(color: coloreSecondario),
            ),
            for (final c in ComponenteBroker.values)
              if (assoc.destinazione(c) case final id?)
                _riga(c, voci.where((v) => v.id == id).firstOrNull, proposta),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      ],
    );
  }

  Widget _riga(ComponenteBroker c, Voce? voce, PropostaConto proposta) {
    final nome = c == ComponenteBroker.liquidita ? 'Liquidità' : 'Investimenti';
    final p = proposta.di(c);
    final righe = <Widget>[
      if (voce == null)
        const Text(
          'Voce non più esistente',
          style: TextStyle(color: coloreNegativo),
        )
      else ...[
        Text('Attuale ${scriviImporto(voce.saldoCentesimi)}'),
        if (p.proponibile) ...[
          Text('Proposto ${scriviImporto(p.centesimi!)}'),
          Text('Differenza ${_differenza(p.centesimi! - voce.saldoCentesimi)}'),
        ] else
          Text(
            'Bloccata: ${p.motivoBlocco}',
            style: const TextStyle(color: coloreNegativo),
          ),
      ],
    ];
    final ammessa = voce != null && p.proponibile;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selezionate.contains(c),
      onChanged: ammessa
          ? (v) => setState(() {
              v == true ? _selezionate.add(c) : _selezionate.remove(c);
            })
          : null,
      title: Text('$nome → ${voce?.nome ?? '—'}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: righe,
      ),
    );
  }
}
