import 'package:flutter/material.dart';

import '../domain/importo.dart';
import '../domain/situazione.dart';
import '../domain/voce.dart';
import 'app_theme.dart';
import 'etichette.dart';

class RiepilogoCategorie extends StatelessWidget {
  const RiepilogoCategorie({
    super.key,
    required this.situazione,
    this.onClassifica,
  });

  final Situazione situazione;
  final void Function(Voce)? onClassifica;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('riepilogo-categorie'),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!situazione.classificazioneCompleta) ...[
          const Text(
            'Classificazione incompleta',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Da classificare: ${scriviImporto(situazione.importoDaClassificare)}',
          ),
          for (final voce in situazione.vociDaClassificare)
            if (onClassifica != null)
              TextButton(
                onPressed: () => onClassifica!(voce),
                child: Text('Classifica ${voce.nome}'),
              )
            else
              Text(voce.nome),
          const SizedBox(height: 4),
        ],
        const Text('Categorie · % sul Totale Investimenti'),
        const SizedBox(height: 4),
        for (final categoria in CategoriaInvestimento.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              key: ValueKey(categoria),
              children: [
                Expanded(child: Text(nomiCategoria[categoria]!)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${scriviImporto(situazione.totaleCategoria(categoria))}  '
                    '${scriviPercentuale(situazione.percentualeCategoria(categoria))}',
                    style: stileImporto,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
