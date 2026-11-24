import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voci_providers.dart';
import '../data/operazioni_coordinator.dart';
import '../domain/importo.dart';
import '../domain/situazione.dart';
import '../domain/voce.dart';

const nomiGruppo = {
  Gruppo.salvadanaio: 'Salvadanaio',
  Gruppo.liquidita: 'Liquidità',
  Gruppo.investimenti: 'Investimenti',
};

const nomiCategoria = {
  CategoriaInvestimento.pianiAccumulo: 'Piani accumulo',
  CategoriaInvestimento.p2pLanding: 'P2P Landing',
  CategoriaInvestimento.depositoTitoli: 'Deposito Titoli',
  CategoriaInvestimento.crypto: 'Crypto',
};

Future<void> cambiaCategoria(
  BuildContext context,
  WidgetRef ref,
  Voce voce,
) async {
  final categoria = await showDialog<CategoriaInvestimento>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('Categoria di ${voce.nome}'),
      children: [
        for (final categoria in CategoriaInvestimento.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, categoria),
            child: Text(nomiCategoria[categoria]!),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
      ],
    ),
  );
  if (categoria == null || !context.mounted) return;
  await modificaVoce(
    context,
    ref,
    voce.id,
    (s) => s.modificaCategoria(voce.id, categoria),
  );
}

/// Runs [f], showing validation and save errors in a snackbar.
Future<void> esegui(BuildContext context, Future<void> Function() f) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await f();
  } on ValidazioneException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on FirebaseException {
    messenger.showSnackBar(
      const SnackBar(content: Text('Modifica non salvata, riprova')),
    );
  } on ModificheBloccateException {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Attendi il completamento della fotografia'),
      ),
    );
  }
}

/// Applies [f] to the current situazione and saves the voce [voceId] it
/// changed. The state is read when applied, never taken from the caller, so
/// close edits do not restore stale values.
Future<void> modificaVoce(
  BuildContext context,
  WidgetRef ref,
  String voceId,
  Situazione Function(Situazione) f,
) => esegui(context, () {
  final coordinator = ref.read(operazioniCoordinatorProvider);
  return coordinator.modifica(
    () => ref
        .read(vociRepositoryProvider)
        .salva(
          f(Situazione(ref.read(vociProvider).value ?? const [])).voci
              .firstWhere((v) => v.id == voceId),
        ),
  );
});

/// Asks for a name; null if cancelled.
Future<String?> chiediNome(
  BuildContext context,
  String titolo,
  String iniziale,
) => showDialog<String>(
  context: context,
  builder: (_) => _NomeDialog(titolo, iniziale),
);

class _NomeDialog extends StatefulWidget {
  const _NomeDialog(this.titolo, this.iniziale);

  final String titolo;
  final String iniziale;

  @override
  State<_NomeDialog> createState() => _NomeDialogState();
}

class _NomeDialogState extends State<_NomeDialog> {
  late final _nome = TextEditingController(text: widget.iniziale);

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titolo),
    content: TextField(controller: _nome, autofocus: true),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _nome.text),
        child: const Text('Salva'),
      ),
    ],
  );
}

Future<void> aggiungiVoce(BuildContext context, WidgetRef ref) async {
  final nuova =
      await showDialog<({String nome, Gruppo gruppo, bool dettaglio})>(
        context: context,
        builder: (_) => const _NuovaVoceDialog(),
      );
  if (nuova == null || !context.mounted) return;
  final id = ref.read(vociRepositoryProvider).nuovoId();
  final voce = nuova.dettaglio
      ? Voce.conDettaglio(id: id, nome: nuova.nome, gruppo: nuova.gruppo)
      : Voce.semplice(id: id, nome: nuova.nome, gruppo: nuova.gruppo);
  await modificaVoce(context, ref, id, (s) => s.aggiungiVoce(voce));
}

class _NuovaVoceDialog extends StatefulWidget {
  const _NuovaVoceDialog();

  @override
  State<_NuovaVoceDialog> createState() => _NuovaVoceDialogState();
}

class _NuovaVoceDialogState extends State<_NuovaVoceDialog> {
  final _nome = TextEditingController();
  var _gruppo = Gruppo.salvadanaio;
  var _conDettaglio = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuova voce'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nome,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final g in Gruppo.values)
              ChoiceChip(
                label: Text(nomiGruppo[g]!),
                selected: _gruppo == g,
                onSelected: (_) => setState(() => _gruppo = g),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Semplice'),
              selected: !_conDettaglio,
              onSelected: (_) => setState(() => _conDettaglio = false),
            ),
            ChoiceChip(
              label: const Text('Con dettaglio'),
              selected: _conDettaglio,
              onSelected: (_) => setState(() => _conDettaglio = true),
            ),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, (
          nome: _nome.text,
          gruppo: _gruppo,
          dettaglio: _conDettaglio,
        )),
        child: const Text('Aggiungi'),
      ),
    ],
  );
}

Future<void> rinominaVoce(
  BuildContext context,
  WidgetRef ref,
  Voce voce,
) async {
  final nome = await chiediNome(context, 'Rinomina voce', voce.nome);
  if (nome == null || !context.mounted) return;
  await modificaVoce(
    context,
    ref,
    voce.id,
    (s) => s.rinominaVoce(voce.id, nome),
  );
}

Future<void> spostaVoce(BuildContext context, WidgetRef ref, Voce voce) async {
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
  await modificaVoce(
    context,
    ref,
    voce.id,
    (s) => s.spostaVoce(voce.id, gruppo),
  );
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
  await esegui(
    context,
    () => ref
        .read(operazioniCoordinatorProvider)
        .modifica(() => ref.read(vociRepositoryProvider).elimina(voce.id)),
  );
}
