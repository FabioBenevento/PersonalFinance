import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/broker_providers.dart';
import '../data/operazioni_coordinator.dart';
import '../data/voci_providers.dart';
import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';
import '../domain/conferma_broker.dart';
import '../domain/importo.dart';
import '../domain/proposta_broker.dart';
import '../domain/voce.dart';
import 'app_theme.dart';

String _giorno(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _differenza(int c) => '${c < 0 ? '-' : '+'}${scriviImporto(c.abs())}';

/// Anteprima del confronto fra saldi attuali e proposti di un conto: non
/// scrive nulla finche l'utente non conferma i saldi selezionati.
class AnteprimaBroker extends ConsumerStatefulWidget {
  const AnteprimaBroker(this.conto, this.rilevazioneId, {super.key});
  final ContoBroker conto;
  final String rilevazioneId;

  @override
  ConsumerState<AnteprimaBroker> createState() => _AnteprimaBrokerState();
}

class _AnteprimaBrokerState extends ConsumerState<AnteprimaBroker> {
  final _selezionate = <ComponenteBroker>{};
  // Una sola operazione per anteprima: un doppio invio non applica due volte.
  late final _operazioneId = ref.read(vociRepositoryProvider).nuovoId();
  late final _repository = ref.read(brokerRepositoryProvider);
  var _inCorso = false;
  String? _errore;
  var _conflitto = false;

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
            if (_errore != null)
              Text(_errore!, style: const TextStyle(color: coloreNegativo)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: _selezionate.isEmpty || _inCorso || _conflitto
              ? null
              : () => _conferma(assoc, voci, proposta),
          child: const Text('Conferma'),
        ),
      ],
    );
  }

  Future<void> _conferma(
    AssociazioniConto assoc,
    List<Voce> voci,
    PropostaConto proposta,
  ) async {
    final conto = widget.conto;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      await ref.read(confermaBrokerProvider)(
        _repository,
        ConfermaBroker(
          operazioneId: _operazioneId,
          rilevazioneId: widget.rilevazioneId,
          associazioni: {conto.id: assoc},
          saldi: [
            for (final c in ComponenteBroker.values)
              if (_selezionate.contains(c))
                SaldoDaConfermare(
                  contoId: conto.id,
                  componente: c,
                  voce: voci.firstWhere((v) => v.id == assoc.destinazione(c)),
                  proposto: proposta.di(c).centesimi!,
                ),
          ],
        ),
      );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Saldi aggiornati')));
    } on ConflittoConfermaException {
      // Nessun ricalcolo: l'utente deve rivedere una nuova anteprima.
      if (mounted) {
        setState(() {
          _inCorso = false;
          _conflitto = true;
          _errore = 'I dati sono cambiati: nessun saldo aggiornato. Chiudi e apri una nuova anteprima.';
        });
      }
    } on ModificheBloccateException {
      if (mounted) {
        setState(() {
          _inCorso = false;
          _errore = 'Fotografia in corso: riprova tra un momento.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _inCorso = false;
          _errore = 'Conferma non riuscita: serve la connessione. Riprova.';
        });
      }
    }
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
      onChanged: ammessa && !_conflitto
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
