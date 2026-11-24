import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fotografie_providers.dart';
import '../domain/fotografia_mensile.dart';
import 'patrimonio_layout.dart';

class AndamentoPage extends ConsumerWidget {
  const AndamentoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotografie = ref.watch(fotografieProvider);
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('PersonalFinance'),
        ),
      ),
      body: PatrimonioLayout(
        destinazione: Destinazione.andamento,
        child: switch (fotografie) {
          AsyncData(:final value) => _contenuto(value),
          AsyncError() => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(fotografieProvider),
              child: const Text('Impossibile leggere le fotografie, riprova'),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _contenuto(List<FotografiaMensile> fotografie) => fotografie.isEmpty
      ? const Center(
          child: Text(
            "Nessuna fotografia salvata: l'andamento comparirà dalla prima fotografia",
          ),
        )
      : const SizedBox.shrink();
}
