import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/andamento.dart';
import '../../domain/importo.dart';
import '../salva_fotografia.dart';

enum _Serie {
  totale('Totale'),
  liquidita('Liquidità con Salvadanaio'),
  investimenti('Investimenti');

  const _Serie(this.nome);
  final String nome;

  int? valore(PuntoMensile p) => switch (this) {
    totale => p.totale,
    liquidita => p.liquiditaConSalvadanaio,
    investimenti => p.investimenti,
  };
}

/// Linee di Totale, Liquidità e Investimenti; i mesi senza valore interrompono
/// la linea.
class GraficoLinee extends StatefulWidget {
  const GraficoLinee({super.key, required this.serie});

  final List<PuntoMensile> serie;

  @override
  State<GraficoLinee> createState() => _GraficoLineeState();
}

class _GraficoLineeState extends State<GraficoLinee> {
  final _nascoste = <_Serie>{};
  int? _selezionato;

  @override
  void didUpdateWidget(GraficoLinee old) {
    super.didUpdateWidget(old);
    if (old.serie.length != widget.serie.length) _selezionato = null;
  }

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;
    final tinte = {
      _Serie.totale: colori.primary,
      _Serie.liquidita: colori.secondary,
      _Serie.investimenti: colori.tertiary,
    };
    final visibili = [
      for (final s in _Serie.values)
        if (!_nascoste.contains(s)) s,
    ];
    final selezionato = _selezionato;
    final punto = selezionato == null || selezionato >= widget.serie.length
        ? null
        : widget.serie[selezionato];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minY: 0,
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(),
                rightTitles: AxisTitles(),
                bottomTitles: AxisTitles(),
                leftTitles: AxisTitles(),
              ),
              lineTouchData: LineTouchData(
                touchSpotThreshold: 10000,
                touchTooltipData: const LineTouchTooltipData(
                  getTooltipItems: _nessunTooltip,
                ),
                touchCallback: (event, risposta) {
                  final spot = risposta?.lineBarSpots?.firstOrNull;
                  if (event is FlTapUpEvent && spot != null) {
                    setState(() => _selezionato = spot.spotIndex);
                  }
                },
              ),
              lineBarsData: [
                for (final s in visibili)
                  LineChartBarData(
                    color: tinte[s],
                    barWidth: 2,
                    spots: [
                      for (var i = 0; i < widget.serie.length; i++)
                        switch (s.valore(widget.serie[i])) {
                          final v? => FlSpot(i.toDouble(), v / 100),
                          null => FlSpot.nullSpot,
                        },
                    ],
                  ),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final s in _Serie.values)
              FilterChip(
                label: Text(s.nome),
                avatar: CircleAvatar(backgroundColor: tinte[s], radius: 5),
                selected: !_nascoste.contains(s),
                showCheckmark: false,
                onSelected: (visibile) => setState(
                  () => visibile ? _nascoste.remove(s) : _nascoste.add(s),
                ),
              ),
          ],
        ),
        if (punto != null) ...[
          const SizedBox(height: 8),
          Text(nomeMese(punto.mese)),
          for (final s in visibili)
            Text(
              '${s.nome}: ${s.valore(punto) == null ? '—' : scriviImporto(s.valore(punto)!)}',
            ),
        ],
      ],
    );
  }
}

List<LineTooltipItem?> _nessunTooltip(List<LineBarSpot> spots) => [
  for (final _ in spots) null,
];
