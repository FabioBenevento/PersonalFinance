import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_theme.dart';

enum Destinazione {
  situazione('Situazione', '/'),
  fotografie('Fotografie', '/fotografie'),
  andamento('Andamento', '/andamento');

  const Destinazione(this.nome, this.path);
  final String nome;
  final String path;
}

class PatrimonioLayout extends StatelessWidget {
  const PatrimonioLayout({
    super.key,
    required this.destinazione,
    required this.child,
  });

  final Destinazione destinazione;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: coloreSuperficie,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final d in Destinazione.values) ...[
                if (d != Destinazione.situazione) const SizedBox(width: 8),
                Expanded(
                  child: _destinazione(
                    context,
                    d.nome,
                    d.path,
                    d == destinazione,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const Divider(),
      Expanded(child: child),
    ],
  );

  Widget _destinazione(
    BuildContext context,
    String nome,
    String path,
    bool selected,
  ) => TextButton(
    style:
        TextButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          foregroundColor: selected ? coloreAzione : coloreSecondario,
        ).copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: selected ? coloreAzione : coloreSuperficie),
          ),
        ),
    onPressed: () => context.go(path),
    child: Text(nome),
  );
}

class DocumentoPatrimonio extends StatelessWidget {
  const DocumentoPatrimonio({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: coloreSuperficie,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: coloreBordo),
      borderRadius: BorderRadius.circular(raggio),
    ),
    child: child,
  );
}
