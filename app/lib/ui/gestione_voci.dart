import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voci_providers.dart';
import '../domain/importo.dart';
import '../domain/situazione.dart';
import '../domain/voce.dart';

const nomiGruppo = {
  Gruppo.salvadanaio: 'Salvadanaio',
  Gruppo.liquidita: 'Liquidità',
  Gruppo.investimenti: 'Investimenti',
};

/// Applies [f] to the current situazione and saves/deletes accordingly,
/// showing validation or save errors in a snackbar.
Future<void> _esegui(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() f,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await f();
  } on ValidazioneException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Modifica non salvata, riprova')),
    );
  }
}

Future<void> aggiungiVoce(
  BuildContext context,
  WidgetRef ref,
  List<Voce> voci,
) async {
  final nome = TextEditingController();
  var gruppo = Gruppo.salvadanaio;
  var conDettaglio = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nuova voce'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final g in Gruppo.values)
                  ChoiceChip(
                    label: Text(nomiGruppo[g]!),
                    selected: gruppo == g,
                    onSelected: (_) => setState(() => gruppo = g),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Semplice'),
                  selected: !conDettaglio,
                  onSelected: (_) => setState(() => conDettaglio = false),
                ),
                ChoiceChip(
                  label: const Text('Con dettaglio'),
                  selected: conDettaglio,
                  onSelected: (_) => setState(() => conDettaglio = true),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final id = DateTime.now().microsecondsSinceEpoch.toString();
  final voce = conDettaglio
      ? Voce.conDettaglio(id: id, nome: nome.text, gruppo: gruppo)
      : Voce.semplice(id: id, nome: nome.text, gruppo: gruppo);
  await _esegui(context, ref, () async {
    final nuova = Situazione(voci).aggiungiVoce(voce);
    await ref
        .read(vociRepositoryProvider)
        .salva(nuova.voci.firstWhere((v) => v.id == id));
  });
}

Future<void> rinominaVoce(
  BuildContext context,
  WidgetRef ref,
  List<Voce> voci,
  Voce voce,
) async {
  final nome = TextEditingController(text: voce.nome);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Rinomina voce'),
      content: TextField(controller: nome, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Salva'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await _esegui(context, ref, () async {
    final nuova = Situazione(voci).rinominaVoce(voce.id, nome.text);
    await ref
        .read(vociRepositoryProvider)
        .salva(nuova.voci.firstWhere((v) => v.id == voce.id));
  });
}

Future<void> spostaVoce(
  BuildContext context,
  WidgetRef ref,
  List<Voce> voci,
  Voce voce,
) async {
  final gruppo = await showDialog<Gruppo>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('Sposta in'),
      children: [
        for (final g in Gruppo.values)
          if (g != voce.gruppo)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, g),
              child: Text(nomiGruppo[g]!),
            ),
      ],
    ),
  );
  if (gruppo == null || !context.mounted) return;
  await _esegui(context, ref, () async {
    final nuova = Situazione(voci).spostaVoce(voce.id, gruppo);
    await ref
        .read(vociRepositoryProvider)
        .salva(nuova.voci.firstWhere((v) => v.id == voce.id));
  });
}

Future<void> eliminaVoce(BuildContext context, WidgetRef ref, Voce voce) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Elimina voce'),
      content: Text(
        'Eliminare "${voce.nome}" (${scriviImporto(voce.saldoCentesimi)})?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Conferma'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await _esegui(
    context,
    ref,
    () => ref.read(vociRepositoryProvider).elimina(voce.id),
  );
}
