import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fotografie_providers.dart';
import '../domain/fotografia_mensile.dart';
import '../domain/andamento.dart';
import '../domain/importo.dart';
import '../domain/mese.dart';
import 'andamento/composizione_torte.dart';
import 'andamento/grafico_area.dart';
import 'andamento/grafico_linee.dart';
import 'andamento/riquadri_variazioni.dart';
import 'patrimonio_layout.dart';
import 'app_theme.dart';
import 'etichette.dart';

const _nomiPeriodo = {
  PeriodoAndamento.dodiciMesi: '12 mesi',
  PeriodoAndamento.annoInCorso: 'Anno in corso',
  PeriodoAndamento.treAnni: '3 anni',
  PeriodoAndamento.tutto: 'Tutto',
};

class AndamentoPage extends ConsumerStatefulWidget {
  const AndamentoPage({super.key});

  @override
  ConsumerState<AndamentoPage> createState() => _AndamentoPageState();
}

class _AndamentoPageState extends ConsumerState<AndamentoPage> {
  var _periodo = PeriodoAndamento.tutto;
  Mese? _meseTorte;

  @override
  Widget build(BuildContext context) {
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
        destinazione: Destinazione.andamento,
        child: switch (fotografie) {
          AsyncData(:final value) => _contenuto(value),
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

  Widget _contenuto(List<FotografiaMensile> fotografie) => fotografie.isEmpty
      ? const Center(
          child: Text(
            "Nessuna fotografia salvata: l'andamento comparirà dalla prima fotografia",
          ),
        )
      : _grafici(fotografie);

  Widget _grafici(List<FotografiaMensile> fotografie) {
    final ultima = ultimaFotografia(fotografie)!;
    final oggi = ref.watch(oggiProvider)();
    final serie = serieMensile(fotografie, _periodo, oggi);
    final recente = serieMensile(fotografie, PeriodoAndamento.tutto, oggi);
    final ultimi24 = recente.sublist(max(0, recente.length - 24));
    final mesi = [...fotografie]..sort((a, b) => b.mese.compareTo(a.mese));
    final scelta = mesi.firstWhere(
      (f) => f.mese == _meseTorte,
      orElse: () => mesi.first,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text('Totale ${nomeMese(ultima.mese)}'),
            subtitle: Text(
              scriviImporto(ultima.situazione.totale),
              style: stileTotale,
            ),
            trailing: SizedBox(
              key: const ValueKey('sparkline-totale'),
              width: 96,
              height: 40,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  titlesData: const FlTitlesData(show: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      color: coloriSerieGrafici[0],
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      spots: [
                        for (var i = 0; i < ultimi24.length; i++)
                          switch (ultimi24[i].totale) {
                            final v? => FlSpot(i.toDouble(), v / 100),
                            null => FlSpot.nullSpot,
                          },
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final p in PeriodoAndamento.values)
              ChoiceChip(
                label: Text(_nomiPeriodo[p]!),
                selected: _periodo == p,
                onSelected: (_) => setState(() => _periodo = p),
              ),
          ],
        ),
        Text('${nomeMese(serie.first.mese)} – ${nomeMese(serie.last.mese)}'),
        GraficoLinee(serie: serie),
        const SizedBox(height: 16),
        const Text('Investimenti per categoria'),
        GraficoArea(serie: serie),
        const SizedBox(height: 16),
        RiquadriVariazioni(variazioni: variazioni(fotografie)!),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text('Composizione di'),
            DropdownButton<Mese>(
              key: const ValueKey('selettore-mese'),
              value: scelta.mese,
              items: [
                for (final f in mesi)
                  DropdownMenuItem(
                    value: f.mese,
                    child: Text(nomeMese(f.mese)),
                  ),
              ],
              onChanged: (m) => setState(() => _meseTorte = m),
            ),
          ],
        ),
        ComposizioneTorte(composizione: composizione(scelta)),
      ],
    );
  }
}
