import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/andamento.dart';
import '../app_theme.dart';
import '../etichette.dart';

/// Tocco o passaggio del mouse: gli eventi che selezionano un valore.
bool eventoDiSelezione(FlTouchEvent e) =>
    e is FlTapUpEvent || e is FlPointerHoverEvent;

/// Pallino e etichetta di una serie; con [onCambia] diventa un filtro che
/// nasconde o mostra la serie.
class VoceLegenda extends StatelessWidget {
  const VoceLegenda({
    super.key,
    required this.colore,
    required this.etichetta,
    this.visibile = true,
    this.onCambia,
  });

  final Color colore;
  final String etichetta;
  final bool visibile;
  final ValueChanged<bool>? onCambia;

  @override
  Widget build(BuildContext context) {
    final pallino = CircleAvatar(backgroundColor: colore, radius: 5);
    if (onCambia == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pallino,
          const SizedBox(width: 8),
          Flexible(child: Text(etichetta)),
        ],
      );
    }
    return FilterChip(
      label: Text(etichetta),
      avatar: pallino,
      selected: visibile,
      showCheckmark: false,
      onSelected: onCambia,
    );
  }
}

/// Valore selezionato in un grafico: titolo e una riga per voce.
class DettaglioSelezione extends StatelessWidget {
  const DettaglioSelezione({
    super.key,
    required this.titolo,
    required this.voci,
  });

  final String titolo;
  final List<({String nome, String importo})> voci;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(titolo),
      for (final v in voci)
        Text.rich(
          TextSpan(
            text: '${v.nome}: ',
            children: [TextSpan(text: v.importo, style: stileImporto)],
          ),
        ),
    ],
  );
}

const _stileAsse = TextStyle(fontSize: 11, color: coloreSecondario);

/// Mesi in basso con intervallo adattivo, importi compatti a sinistra.
FlTitlesData assiGrafico(List<PuntoMensile> serie) => FlTitlesData(
  topTitles: const AxisTitles(),
  rightTitles: const AxisTitles(),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 24,
      interval: max(1, (serie.length / 5).ceil()).toDouble(),
      getTitlesWidget: (x, meta) {
        final i = x.round();
        if (i < 0 || i >= serie.length) return const SizedBox.shrink();
        final m = serie[i].mese;
        return SideTitleWidget(
          meta: meta,
          child: Text(
            '${nomiMesi[m.mese - 1].substring(0, 3).toLowerCase()} '
            '${m.anno % 100}',
            style: _stileAsse,
          ),
        );
      },
    ),
  ),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 56,
      getTitlesWidget: (v, meta) => SideTitleWidget(
        meta: meta,
        child: Text(scriviCompatto(v), style: _stileAsse),
      ),
    ),
  ),
);

/// Il valore selezionato si legge sotto il grafico, non in un tooltip.
List<LineTooltipItem?> nessunTooltip(List<LineBarSpot> spots) => [
  for (final _ in spots) null,
];
