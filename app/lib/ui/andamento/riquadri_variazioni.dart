import 'package:flutter/material.dart';

import '../../domain/andamento.dart';
import '../../domain/importo.dart';
import '../salva_fotografia.dart';

String _firmato(String Function(int) scrivi, int v) =>
    '${v < 0 ? '-' : '+'}${scrivi(v.abs())}';

/// Variazione del Totale rispetto a un mese di confronto.
class _Riquadro extends StatelessWidget {
  const _Riquadro({required super.key, required this.titolo, required this.v});

  final String titolo;
  final Variazione v;

  @override
  Widget build(BuildContext context) {
    final d = v.differenza;
    final p = v.percentuale;
    return SizedBox(
      width: 200,
      child: Card(
        child: ListTile(
          title: Text(titolo),
          subtitle: d == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('—'),
                    Text(
                      'nessuna fotografia di ${nomeMese(v.confronto).toLowerCase()}',
                    ),
                  ],
                )
              : Text(
                  '${_firmato(scriviImporto, d)} · '
                  '${p == null ? '—' : _firmato(scriviPercentuale, p)}',
                ),
        ),
      ),
    );
  }
}

class RiquadriVariazioni extends StatelessWidget {
  const RiquadriVariazioni({super.key, required this.variazioni});

  final VariazioniTotale variazioni;

  @override
  Widget build(BuildContext context) => Wrap(
    children: [
      _Riquadro(
        key: const ValueKey('variazione-precedente'),
        titolo: 'Mese precedente',
        v: variazioni.precedente,
      ),
      _Riquadro(
        key: const ValueKey('variazione-gennaio'),
        titolo: 'Da gennaio',
        v: variazioni.gennaio,
      ),
      _Riquadro(
        key: const ValueKey('variazione-anno'),
        titolo: 'Anno precedente',
        v: variazioni.annoPrecedente,
      ),
    ],
  );
}
