import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth.dart';
import '../data/voci_providers.dart';
import '../domain/importo.dart';
import '../domain/situazione.dart';
import '../domain/voce.dart';
import 'dettaglio_page.dart';
import 'gestione_voci.dart';
import 'saldo_editor.dart';
import 'salva_fotografia.dart';
import 'app_theme.dart';
import 'patrimonio_layout.dart';

class SituazionePage extends ConsumerWidget {
  const SituazionePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(vociProvider);
    final bloccato = ref.watch(operazioniBloccateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('PersonalFinance'),
        ),
        actions: [
          IconButton(
            tooltip: 'Fotografie mensili',
            onPressed: () => context.push('/fotografie'),
            icon: const Icon(Icons.history),
          ),
          if (voci.hasValue && MediaQuery.sizeOf(context).width < 700)
            IconButton(
              tooltip: 'Aggiungi voce',
              onPressed: bloccato ? null : () => aggiungiVoce(context, ref),
              icon: const Icon(Icons.add),
            )
          else if (voci.hasValue)
            TextButton(
              onPressed: bloccato ? null : () => aggiungiVoce(context, ref),
              child: const Text(
                'Aggiungi voce',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (MediaQuery.sizeOf(context).width < 700)
            IconButton(
              tooltip: 'Esci',
              onPressed: ref.read(authGatewayProvider).signOut,
              icon: const Icon(Icons.logout),
            )
          else
            TextButton(
              onPressed: ref.read(authGatewayProvider).signOut,
              child: const Text('Esci', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: PatrimonioLayout(
        storico: false,
        child: switch (voci) {
          AsyncData(:final value) => _Elenco(Situazione(value)),
          AsyncError() => const Center(
            child: Text('Impossibile leggere le voci'),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Elenco extends StatelessWidget {
  const _Elenco(this.situazione);

  final Situazione situazione;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1048),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 700 ? 12 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (MediaQuery.sizeOf(context).width >= 700)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Situazione Patrimoniale',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const SalvaFotografiaButton(),
                ],
              )
            else ...[
              Text(
                'Situazione Patrimoniale',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const SalvaFotografiaButton(),
            ],
            const SizedBox(height: 8),
            const Text('I tuoi saldi di oggi, divisi nei tre gruppi.'),
            const SizedBox(height: 24),
            Expanded(
              child: DocumentoPatrimonio(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('I saldi di oggi'),
                          const SizedBox(height: 16),
                          const Text(
                            'PATRIMONIO TOTALE',
                            style: TextStyle(
                              fontSize: 12,
                              color: coloreSecondario,
                            ),
                          ),
                          Text(
                            scriviImporto(situazione.totale),
                            style: stileCifre.copyWith(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final g in Gruppo.values) ...[
                      _Riepilogo(
                        nome: nomiGruppo[g]!,
                        saldo: situazione.totaleGruppo(g),
                        percentuale: scriviPercentuale(
                          situazione.percentualeGruppo(g),
                        ),
                        grassetto: true,
                      ),
                      for (final v in situazione.voci.where(
                        (v) => v.gruppo == g,
                      ))
                        _VoceRow(
                          key: ValueKey(v.id),
                          voce: v,
                          percentuale: scriviPercentuale(
                            situazione.percentualeVoce(v),
                          ),
                        ),
                    ],
                    _Riepilogo(
                      nome: 'Totale',
                      saldo: situazione.totale,
                      percentuale: null,
                      grassetto: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
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
    final stretto = MediaQuery.sizeOf(context).width < 700;
    return Container(
      color: coloreSelezione,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(nome, style: stile)),
          const SizedBox(width: 8),
          if (stretto)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(scriviImporto(saldo), style: stileCifre),
                if (percentuale != null)
                  Text(percentuale!, style: stileCifre.copyWith(fontSize: 12)),
              ],
            )
          else
            Text(
              [scriviImporto(saldo), ?percentuale].join('  '),
              style: stileCifre.merge(stile),
            ),
        ],
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
    final bloccato = ref.watch(operazioniBloccateProvider);
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
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voce.nome),
                  if (voce.categoria != null)
                    Text(
                      nomiCategoria[voce.categoria]!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (inAttesa)
                    Text(
                      testoInAttesa,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width < 700)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (voce.conDettaglio)
                    Text(scriviImporto(voce.saldoCentesimi), style: stileCifre)
                  else
                    SaldoEditor(
                      saldoCentesimi: voce.saldoCentesimi,
                      enabled: !bloccato,
                      onSalva: (c) => modificaVoce(
                        context,
                        ref,
                        voce.id,
                        (s) => s.modificaSaldoVoce(voce.id, c),
                      ),
                    ),
                  Text(percentuale, style: stileCifre.copyWith(fontSize: 12)),
                ],
              )
            else if (voce.conDettaglio)
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
                enabled: !bloccato,
                onSalva: (c) => modificaVoce(
                  context,
                  ref,
                  voce.id,
                  (s) => s.modificaSaldoVoce(voce.id, c),
                ),
              ),
            const SizedBox(width: 8),
            if (MediaQuery.sizeOf(context).width >= 700) Text(percentuale),
            PopupMenuButton<String>(
              tooltip: 'Azioni ${voce.nome}',
              enabled: !bloccato,
              onSelected: (azione) {
                switch (azione) {
                  case 'categoria':
                    cambiaCategoria(context, ref, voce);
                  case 'rinomina':
                    rinominaVoce(context, ref, voce);
                  case 'sposta':
                    spostaVoce(context, ref, voce);
                  case 'elimina':
                    eliminaVoce(context, ref, voce);
                }
              },
              itemBuilder: (_) => [
                if (voce.gruppo == Gruppo.investimenti)
                  const PopupMenuItem(
                    value: 'categoria',
                    child: Text('Categoria'),
                  ),
                const PopupMenuItem(value: 'rinomina', child: Text('Rinomina')),
                const PopupMenuItem(value: 'sposta', child: Text('Sposta')),
                const PopupMenuItem(value: 'elimina', child: Text('Elimina')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
