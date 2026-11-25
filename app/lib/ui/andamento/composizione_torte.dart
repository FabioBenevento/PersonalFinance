import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/andamento.dart';
import '../../domain/importo.dart';
import '../../domain/voce.dart';
import '../app_theme.dart';
import '../etichette.dart';
import 'elementi_grafico.dart';

typedef _Fetta = ({String nome, Quota quota});

String _quota(Quota q) =>
    '${scriviImporto(q.importo)}  ${scriviPercentuale(q.percentuale)}';

/// Torta con elenco di importi e percentuali; al tocco o al passaggio del mouse
/// mostra la fetta sotto il grafico.
class _Torta extends StatefulWidget {
  const _Torta({required super.key, required this.titolo, required this.fette});

  final String titolo;
  final List<_Fetta> fette;

  @override
  State<_Torta> createState() => _TortaState();
}

class _TortaState extends State<_Torta> {
  int? _selezionata;

  @override
  Widget build(BuildContext context) {
    final fette = widget.fette;
    final selezionata = _selezionata;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.titolo, style: Theme.of(context).textTheme.titleSmall),
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 30,
              sectionsSpace: 1,
              pieTouchData: PieTouchData(
                touchCallback: (event, risposta) {
                  final i = risposta?.touchedSection?.touchedSectionIndex;
                  if (eventoDiSelezione(event) && i != null && i >= 0) {
                    setState(() => _selezionata = i);
                  }
                },
              ),
              sections: [
                for (var i = 0; i < fette.length; i++)
                  PieChartSectionData(
                    value: fette[i].quota.importo / 100,
                    color: coloriSerieGrafici[i],
                    title: '',
                    radius: 50,
                  ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < fette.length; i++)
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: VoceLegenda(
                    colore: coloriSerieGrafici[i],
                    etichetta: fette[i].nome,
                  ),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_quota(fette[i].quota), style: stileImporto),
                ),
              ),
            ],
          ),
        if (selezionata != null && selezionata < fette.length)
          DettaglioSelezione(
            titolo: fette[selezionata].nome,
            voci: [
              (nome: 'Importo', importo: _quota(fette[selezionata].quota)),
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
          fette: [
            for (final g in Gruppo.values)
              (nome: nomiGruppo[g]!, quota: composizione.gruppi[g]!),
          ],
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
            fette: [
              for (final c in CategoriaInvestimento.values)
                (nome: nomiCategoria[c]!, quota: categorie[c]!),
            ],
          ),
      ],
    );
  }
}
