import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/andamento.dart';
import '../../domain/importo.dart';
import '../../domain/voce.dart';
import '../etichette.dart';
import 'grafico_area.dart';

/// Torta con elenco di importi e percentuali.
class _Torta extends StatelessWidget {
  const _Torta({
    required super.key,
    required this.titolo,
    required this.nomi,
    required this.quote,
  });

  final String titolo;
  final List<String> nomi;
  final List<Quota> quote;

  @override
  Widget build(BuildContext context) {
    final colori = coloriSerie(Theme.of(context).colorScheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titolo, style: Theme.of(context).textTheme.titleSmall),
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 30,
              sectionsSpace: 1,
              sections: [
                for (var i = 0; i < quote.length; i++)
                  PieChartSectionData(
                    value: quote[i].importo / 100,
                    color: colori[i],
                    title: '',
                    radius: 50,
                  ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < quote.length; i++)
          Row(
            children: [
              CircleAvatar(backgroundColor: colori[i], radius: 5),
              const SizedBox(width: 8),
              Expanded(child: Text(nomi[i])),
              Text(
                '${scriviImporto(quote[i].importo)}  '
                '${scriviPercentuale(quote[i].percentuale)}',
              ),
            ],
          ),
      ],
    );
  }
}

/// Torte per gruppo e per categoria di un mese.
class ComposizioneTorte extends StatelessWidget {
  const ComposizioneTorte({super.key, required this.composizione});

  final Composizione composizione;

  @override
  Widget build(BuildContext context) {
    final categorie = composizione.categorie;
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _Torta(
          key: const ValueKey('torta-gruppi'),
          titolo: 'Per gruppo',
          nomi: [for (final g in Gruppo.values) nomiGruppo[g]!],
          quote: composizione.gruppi.values.toList(),
        ),
        if (categorie == null)
          const Text(
            key: ValueKey('torta-categorie-non-disponibile'),
            'Riepilogo per categoria non disponibile',
          )
        else
          _Torta(
            key: const ValueKey('torta-categorie'),
            titolo: 'Investimenti per categoria',
            nomi: [
              for (final c in CategoriaInvestimento.values) nomiCategoria[c]!,
            ],
            quote: categorie.values.toList(),
          ),
      ],
    );
  }
}
