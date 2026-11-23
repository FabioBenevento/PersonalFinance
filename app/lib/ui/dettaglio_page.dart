import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voci_providers.dart';
import '../domain/importo.dart';
import '../domain/situazione.dart';
import '../domain/voce.dart';

/// Righe di una voce con dettaglio; il saldo della voce è la somma delle righe.
class DettaglioPage extends ConsumerWidget {
  const DettaglioPage({super.key, required this.voceId});

  final String voceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(vociProvider).value ?? const <Voce>[];
    final voce = voci.where((v) => v.id == voceId).firstOrNull;
    if (voce == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(title: Text(voce.nome)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _aggiungi(context, ref, voci),
        label: const Text('Aggiungi riga'),
        icon: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            title: const Text(
              'Saldo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Text(
              scriviImporto(voce.saldoCentesimi),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final r in voce.righe!)
            _RigaRow(
              key: ValueKey(r.id),
              riga: r,
              onSaldo: (c) => _applica(
                context,
                ref,
                voci,
                (s) => s.modificaSaldoRiga(voceId, r.id, c),
              ),
              onRinomina: () => _rinomina(context, ref, voci, r),
              onElimina: () => _applica(
                context,
                ref,
                voci,
                (s) => s.eliminaRiga(voceId, r.id),
              ),
            ),
        ],
      ),
    );
  }

  /// Applies [f] to the situazione and saves the changed voce.
  Future<void> _applica(
    BuildContext context,
    WidgetRef ref,
    List<Voce> voci,
    Situazione Function(Situazione) f,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final nuova = f(Situazione(voci));
      await ref
          .read(vociRepositoryProvider)
          .salva(nuova.voci.firstWhere((v) => v.id == voceId));
    } on ValidazioneException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Modifica non salvata, riprova')),
      );
    }
  }

  Future<void> _aggiungi(
    BuildContext context,
    WidgetRef ref,
    List<Voce> voci,
  ) async {
    final nome = TextEditingController();
    final saldo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuova riga'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: saldo,
              decoration: const InputDecoration(labelText: 'Saldo'),
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
    );
    if (ok != true || !context.mounted) return;
    final centesimi = saldo.text.trim().isEmpty ? 0 : leggiImporto(saldo.text);
    if (centesimi == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(messaggioImportoNonValido)));
      return;
    }
    await _applica(
      context,
      ref,
      voci,
      (s) => s.aggiungiRiga(
        voceId,
        Riga(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          nome: nome.text,
          saldoCentesimi: centesimi,
        ),
      ),
    );
  }

  Future<void> _rinomina(
    BuildContext context,
    WidgetRef ref,
    List<Voce> voci,
    Riga riga,
  ) async {
    final nome = TextEditingController(text: riga.nome);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rinomina riga'),
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
    await _applica(
      context,
      ref,
      voci,
      (s) => s.rinominaRiga(voceId, riga.id, nome.text),
    );
  }
}

class _RigaRow extends StatefulWidget {
  const _RigaRow({
    super.key,
    required this.riga,
    required this.onSaldo,
    required this.onRinomina,
    required this.onElimina,
  });

  final Riga riga;
  final Future<void> Function(int centesimi) onSaldo;
  final VoidCallback onRinomina;
  final VoidCallback onElimina;

  @override
  State<_RigaRow> createState() => _RigaRowState();
}

class _RigaRowState extends State<_RigaRow> {
  late final _controller = TextEditingController(text: _saldo);
  final _focus = FocusNode();

  String get _saldo => scriviImporto(widget.riga.saldoCentesimi);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _salva();
    });
  }

  @override
  void didUpdateWidget(_RigaRow old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus) _controller.text = _saldo;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    final centesimi = leggiImporto(_controller.text);
    if (centesimi == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(messaggioImportoNonValido)));
    } else if (centesimi != widget.riga.saldoCentesimi) {
      await widget.onSaldo(centesimi);
    }
    if (mounted) _controller.text = _saldo;
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(widget.riga.nome),
    trailing: SizedBox(
      width: 260,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textAlign: TextAlign.end,
              onSubmitted: (_) => _salva(),
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
          IconButton(
            tooltip: 'Rinomina ${widget.riga.nome}',
            icon: const Icon(Icons.edit),
            onPressed: widget.onRinomina,
          ),
          IconButton(
            tooltip: 'Elimina ${widget.riga.nome}',
            icon: const Icon(Icons.delete),
            onPressed: widget.onElimina,
          ),
        ],
      ),
    ),
  );
}
