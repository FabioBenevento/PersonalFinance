import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_theme.dart';

class PatrimonioLayout extends StatelessWidget {
  const PatrimonioLayout({
    super.key,
    required this.storico,
    required this.child,
  });

  final bool storico;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _destinazione(context, 'Situazione', '/', !storico),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _destinazione(
                  context,
                  'Fotografie',
                  '/fotografie',
                  storico,
                ),
              ),
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
    style: TextButton.styleFrom(
      backgroundColor: selected ? coloreSelezione : null,
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
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: coloreBordo),
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
}
