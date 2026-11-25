import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/andamento.dart';
import '../../domain/importo.dart';
import '../../domain/voce.dart';
import '../app_theme.dart';
import '../etichette.dart';
import 'elementi_grafico.dart';

/// Area impilata degli Investimenti per categoria; i mesi senza fotografia o
/// di schema 1 interrompono l'area.
class GraficoArea extends StatefulWidget {
  const GraficoArea({super.key, required this.serie});

  final List<PuntoMensile> serie;

  @override
  State<GraficoArea> createState() => _GraficoAreaState();
}

class _GraficoAreaState extends State<GraficoArea> {
  static const _categorie = CategoriaInvestimento.values;
  final _nascoste = <CategoriaInvestimento>{};
  int? _selezionato;

  @override
  void didUpdateWidget(GraficoArea old) {
    super.didUpdateWidget(old);
    if (old.serie.length != widget.serie.length ||
        old.serie.firstOrNull?.mese != widget.serie.firstOrNull?.mese) {
      _selezionato = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final serie = widget.serie;
    final visibili = [
      for (final c in _categorie)
        if (!_nascoste.contains(c)) c,
    ];
    // Ogni area è il cumulato fino alla categoria; le più alte si disegnano per
    // prime così le inferiori le ricoprono.
    LineChartBarData area(CategoriaInvestimento c) => LineChartBarData(
      color: coloriSerieGrafici[c.index],
      barWidth: 0,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: coloriSerieGrafici[c.index]),
      spots: [
        for (var x = 0; x < serie.length; x++)
          switch (serie[x].cumulato(c, nascoste: _nascoste)) {
            final v? => FlSpot(x.toDouble(), v / 100),
            null => FlSpot.nullSpot,
          },
      ],
    );
    final selezionato = _selezionato;
    final punto = selezionato == null || selezionato >= serie.length
        ? null
        : serie[selezionato];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              titlesData: assiGrafico(serie),
              lineTouchData: LineTouchData(
                touchSpotThreshold: 10000,
                touchTooltipData: const LineTouchTooltipData(
                  getTooltipItems: nessunTooltip,
                ),
                touchCallback: (event, risposta) {
                  final spot = risposta?.lineBarSpots?.firstOrNull;
                  if (eventoDiSelezione(event) && spot != null) {
                    setState(() => _selezionato = spot.spotIndex);
                  }
                },
              ),
              lineBarsData: [for (final c in visibili.reversed) area(c)],
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final c in _categorie)
              VoceLegenda(
                colore: coloriSerieGrafici[c.index],
                etichetta: nomiCategoria[c]!,
                visibile: !_nascoste.contains(c),
                onCambia: (v) =>
                    setState(() => v ? _nascoste.remove(c) : _nascoste.add(c)),
              ),
          ],
        ),
        if (punto != null)
          DettaglioSelezione(
            titolo: nomeMese(punto.mese),
            voci: [
              for (final c in visibili)
                (
                  nome: nomiCategoria[c]!,
                  importo: punto.categorie == null
                      ? '—'
                      : scriviImporto(punto.categorie![c]!),
                ),
            ],
          ),
      ],
    );
  }
}
