import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/fotografie_providers.dart';
import '../domain/fotografia_mensile.dart';
import '../domain/importo.dart';
import '../domain/mese.dart';
import '../domain/voce.dart';
import 'app_theme.dart';
import 'etichette.dart';
import 'patrimonio_layout.dart';
import 'riepilogo_categorie.dart';

class FotografiePage extends ConsumerWidget {
  const FotografiePage({super.key, this.meseId});
  final String? meseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotografie = ref.watch(fotografieProvider);
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('PersonalFinance'),
        ),
      ),
      body: PatrimonioLayout(
        destinazione: Destinazione.fotografie,
        child: switch (fotografie) {
          AsyncData(:final value) => _contenuto(context, value),
          AsyncError() => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(fotografieProvider),
              child: const Text('Impossibile leggere le fotografie, riprova'),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _contenuto(BuildContext context, List<FotografiaMensile> fotografie) {
    if (meseId != null) {
      try {
        Mese.fromId(meseId!);
      } on ValidazioneException {
        return const Center(child: Text('Mese non valido'));
      }
    }
    if (fotografie.isEmpty && meseId == null) {
      return const Center(child: Text('Nessuna fotografia salvata'));
    }
    final ordinate = fotografie.toList()
      ..sort((a, b) => b.mese.compareTo(a.mese));
    final selezionata = meseId == null
        ? ordinate.firstOrNull
        : ordinate.where((f) => f.mese.id == meseId).firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 700;
        final archivio = DocumentoPatrimonio(
          child: ListView(
            key: const ValueKey('archivio-fotografie'),
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Archivio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (var i = 0; i < ordinate.length; i++) ...[
                if (i == 0 ||
                    ordinate[i - 1].mese.anno != ordinate[i].mese.anno)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      '${ordinate[i].mese.anno}',
                      style: const TextStyle(color: coloreSecondario),
                    ),
                  ),
                ListTile(
                  selected:
                      ordinate[i].mese.id == selezionata?.mese.id &&
                      (desktop || meseId != null),
                  selectedTileColor: coloreSelezione,
                  title: Text(nomeMese(ordinate[i].mese)),
                  subtitle: Text(
                    scriviImporto(ordinate[i].situazione.totale),
                    style: stileImporto,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/fotografie/${ordinate[i].mese.id}'),
                ),
              ],
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Compaiono solo i mesi salvati.',
                  style: TextStyle(color: coloreSecondario),
                ),
              ),
            ],
          ),
        );
        final documento = selezionata == null
            ? const Center(child: Text('Fotografia non trovata'))
            : _FotografiaDocumento(selezionata);
        return Padding(
          padding: EdgeInsets.all(desktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!desktop && meseId != null)
                TextButton.icon(
                  onPressed: () => context.go('/fotografie'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Tutte le fotografie'),
                )
              else ...[
                Text(
                  'Fotografie mensili',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('I tuoi saldi, conservati mese per mese.'),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 260, child: archivio),
                          const SizedBox(width: 24),
                          Expanded(child: documento),
                        ],
                      )
                    : meseId == null
                    ? archivio
                    : documento,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FotografiaDocumento extends StatelessWidget {
  const _FotografiaDocumento(this.fotografia);
  final FotografiaMensile fotografia;

  @override
  Widget build(BuildContext context) {
    final situazione = fotografia.situazione;
    return DocumentoPatrimonio(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FOTOGRAFIA MENSILE',
                  style: TextStyle(color: coloreSecondario, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  nomeMese(fotografia.mese),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sola lettura',
                  style: TextStyle(color: coloreAzione),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PATRIMONIO TOTALE',
                  style: TextStyle(color: coloreSecondario, fontSize: 12),
                ),
                Text(scriviImporto(situazione.totale), style: stileTotale),
              ],
            ),
          ),
          for (final gruppo in Gruppo.values) ...[
            _Valori(
              nome: nomiGruppo[gruppo]!,
              saldo: situazione.totaleGruppo(gruppo),
              percentuale: scriviPercentuale(
                situazione.percentualeGruppo(gruppo),
              ),
              gruppo: true,
            ),
            for (final voce in situazione.voci.where((v) => v.gruppo == gruppo))
              if (voce.conDettaglio)
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(voce.nome),
                  trailing: _Cifre(
                    saldo: voce.saldoCentesimi,
                    percentuale: scriviPercentuale(
                      situazione.percentualeVoce(voce),
                    ),
                  ),
                  children: [
                    for (final riga in voce.righe!)
                      _Valori(
                        nome: riga.nome,
                        saldo: riga.saldoCentesimi,
                        riga: true,
                      ),
                  ],
                )
              else
                _Valori(
                  nome: voce.nome,
                  saldo: voce.saldoCentesimi,
                  percentuale: scriviPercentuale(
                    situazione.percentualeVoce(voce),
                  ),
                ),
          ],
          if (fotografia.haCategorie)
            RiepilogoCategorie(situazione: situazione)
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Riepilogo per categoria non disponibile',
                style: TextStyle(color: coloreSecondario),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Questi saldi conservano i dettagli del mese scelto.',
              style: TextStyle(color: coloreSecondario),
            ),
          ),
        ],
      ),
    );
  }
}

class _Valori extends StatelessWidget {
  const _Valori({
    required this.nome,
    required this.saldo,
    this.percentuale,
    this.gruppo = false,
    this.riga = false,
  });
  final String nome;
  final int saldo;
  final String? percentuale;
  final bool gruppo;
  final bool riga;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: gruppo ? coloreSelezione : null,
      border: const Border(top: BorderSide(color: coloreBordo)),
    ),
    padding: EdgeInsets.fromLTRB(riga ? 32 : 16, 14, 16, 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            nome,
            style: TextStyle(
              fontWeight: gruppo ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _Cifre(saldo: saldo, percentuale: percentuale),
      ],
    ),
  );
}

class _Cifre extends StatelessWidget {
  const _Cifre({required this.saldo, this.percentuale});
  final int saldo;
  final String? percentuale;

  @override
  Widget build(BuildContext context) {
    final importo = Text(scriviImporto(saldo), style: stileImporto);
    final quota = Text(percentuale ?? '', style: stileImportoSecondario);
    return MediaQuery.sizeOf(context).width < 700
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [importo, if (percentuale != null) quota],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              importo,
              SizedBox(
                width: 80,
                child: Align(alignment: Alignment.centerRight, child: quota),
              ),
            ],
          );
  }
}
