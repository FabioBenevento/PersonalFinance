import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../data/voci_providers.dart';
import '../domain/importo.dart';
import '../domain/situazione.dart';
import '../domain/voce.dart';
import 'dettaglio_page.dart';
import 'gestione_voci.dart';
import 'saldo_editor.dart';

class SituazionePage extends ConsumerWidget {
  const SituazionePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(vociProvider);
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('PersonalFinance'),
        ),
        actions: [
          if (voci.value case final v?)
            TextButton(
              onPressed: () => aggiungiVoce(context, ref, v),
              child: const Text('Aggiungi voce'),
            ),
          TextButton(
            onPressed: ref.read(authGatewayProvider).signOut,
            child: const Text('Esci'),
          ),
        ],
      ),
      body: switch (voci) {
        AsyncData(:final value) => _Elenco(Situazione(value)),
        AsyncError() => const Center(
          child: Text('Impossibile leggere le voci'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Elenco extends StatelessWidget {
  const _Elenco(this.situazione);

  final Situazione situazione;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final g in Gruppo.values) ...[
        _Riepilogo(
          nome: nomiGruppo[g]!,
          saldo: situazione.totaleGruppo(g),
          percentuale: scriviPercentuale(situazione.percentualeGruppo(g)),
          grassetto: true,
        ),
        for (final v in situazione.voci.where((v) => v.gruppo == g))
          _VoceRow(
            key: ValueKey(v.id),
            voce: v,
            percentuale: scriviPercentuale(situazione.percentualeVoce(v)),
          ),
      ],
      _Riepilogo(
        nome: 'Totale',
        saldo: situazione.totale,
        percentuale: null,
        grassetto: true,
      ),
    ],
  );
}

class _Riepilogo extends StatelessWidget {
  const _Riepilogo({
    required this.nome,
    required this.saldo,
    required this.percentuale,
    required this.grassetto,
  });

  final String nome;
  final int saldo;
  final String? percentuale;
  final bool grassetto;

  @override
  Widget build(BuildContext context) {
    final stile = grassetto
        ? const TextStyle(fontWeight: FontWeight.bold)
        : null;
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      title: Text(nome, style: stile),
      trailing: Text(
        [scriviImporto(saldo), ?percentuale].join('  '),
        style: stile,
      ),
    );
  }
}

class _VoceRow extends ConsumerWidget {
  const _VoceRow({super.key, required this.voce, required this.percentuale});

  final Voce voce;
  final String percentuale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inAttesa =
        ref.watch(vociInAttesaProvider).value?.contains(voce.id) ?? false;
    return InkWell(
      onTap: voce.conDettaglio
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DettaglioPage(voceId: voce.id),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voce.nome),
                  if (inAttesa)
                    Text(
                      testoInAttesa,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (voce.conDettaglio)
              SizedBox(
                width: larghezzaSaldo,
                child: Text(
                  scriviImporto(voce.saldoCentesimi),
                  textAlign: TextAlign.end,
                ),
              )
            else
              SaldoEditor(
                saldoCentesimi: voce.saldoCentesimi,
                onSalva: (c) => modificaVoce(
                  context,
                  ref,
                  ref.read(vociProvider).value ?? const [],
                  voce.id,
                  (s) => s.modificaSaldoVoce(voce.id, c),
                ),
              ),
            const SizedBox(width: 8),
            Text(percentuale),
            PopupMenuButton<String>(
              tooltip: 'Azioni ${voce.nome}',
              onSelected: (azione) {
                final voci = ref.read(vociProvider).value ?? const [];
                switch (azione) {
                  case 'rinomina':
                    rinominaVoce(context, ref, voci, voce);
                  case 'sposta':
                    spostaVoce(context, ref, voci, voce);
                  case 'elimina':
                    eliminaVoce(context, ref, voce);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rinomina', child: Text('Rinomina')),
                PopupMenuItem(value: 'sposta', child: Text('Sposta')),
                PopupMenuItem(value: 'elimina', child: Text('Elimina')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
