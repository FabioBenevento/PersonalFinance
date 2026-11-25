import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/andamento.dart';
import '../../domain/voce.dart';
import '../etichette.dart';

List<Color> coloriSerie(ColorScheme c) => [
  c.primary,
  c.secondary,
  c.tertiary,
  c.onSurfaceVariant,
];

/// Area impilata degli Investimenti per categoria; i mesi senza fotografia o
/// di schema 1 interrompono l'area.
class GraficoArea extends StatelessWidget {
  const GraficoArea({super.key, required this.serie});

  final List<PuntoMensile> serie;

  @override
  Widget build(BuildContext context) {
    final colori = coloriSerie(Theme.of(context).colorScheme);
    const categorie = CategoriaInvestimento.values;
    // Ogni area è il cumulato fino alla categoria; le più alte si disegnano per
    // prime così le inferiori le ricoprono.
    LineChartBarData area(int i) => LineChartBarData(
      color: colori[i],
      barWidth: 0,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: colori[i]),
      spots: [
        for (var x = 0; x < serie.length; x++)
          switch (serie[x].categorie) {
            final c? => FlSpot(
              x.toDouble(),
              categorie.take(i + 1).fold(0, (s, k) => s + c[k]!) / 100,
            ),
            null => FlSpot.nullSpot,
          },
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(),
                rightTitles: AxisTitles(),
                bottomTitles: AxisTitles(),
                leftTitles: AxisTitles(),
              ),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                for (var i = categorie.length - 1; i >= 0; i--) area(i),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            for (var i = 0; i < categorie.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(backgroundColor: colori[i], radius: 5),
                  const SizedBox(width: 4),
                  Text(nomiCategoria[categorie[i]]!),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
