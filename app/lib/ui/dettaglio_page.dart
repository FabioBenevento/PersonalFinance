import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voci_providers.dart';
import '../domain/importo.dart';
import '../domain/voce.dart';
import 'gestione_voci.dart';
import 'saldo_editor.dart';

const testoInAttesa = 'In attesa di sincronizzazione';

/// Righe di una voce con dettaglio; il saldo della voce è la somma delle righe.
class DettaglioPage extends ConsumerWidget {
  const DettaglioPage({super.key, required this.voceId});

  final String voceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caricate = ref.watch(vociProvider).value;
    if (caricate == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final voce = caricate.where((v) => v.id == voceId).firstOrNull;
    if (voce == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Voce non più disponibile')),
      );
    }
    final inAttesa =
        ref.watch(vociInAttesaProvider).value?.contains(voceId) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(voce.nome),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _aggiungi(context, ref, caricate),
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
            subtitle: inAttesa ? const Text(testoInAttesa) : null,
            trailing: Text(
              scriviImporto(voce.saldoCentesimi),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final r in voce.righe!)
            _RigaRow(
              key: ValueKey(r.id),
              riga: r,
              onSaldo: (c) => modificaVoce(
                context,
                ref,
                caricate,
                voceId,
                (s) => s.modificaSaldoRiga(voceId, r.id, c),
              ),
              onRinomina: () => _rinomina(context, ref, caricate, r),
              onElimina: () => modificaVoce(
                context,
                ref,
                caricate,
                voceId,
                (s) => s.eliminaRiga(voceId, r.id),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _aggiungi(
    BuildContext context,
    WidgetRef ref,
    List<Voce> voci,
  ) async {
    final dati = await showDialog<({String nome, String saldo})>(
      context: context,
      builder: (_) => const _NuovaRigaDialog(),
    );
    if (dati == null || !context.mounted) return;
    final centesimi = dati.saldo.trim().isEmpty ? 0 : leggiImporto(dati.saldo);
    if (centesimi == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(messaggioImportoNonValido)));
      return;
    }
    final id = ref.read(vociRepositoryProvider).nuovoId();
    await modificaVoce(
      context,
      ref,
      voci,
      voceId,
      (s) => s.aggiungiRiga(
        voceId,
        Riga(id: id, nome: dati.nome, saldoCentesimi: centesimi),
      ),
    );
  }

  Future<void> _rinomina(
    BuildContext context,
    WidgetRef ref,
    List<Voce> voci,
    Riga riga,
  ) async {
    final nome = await chiediNome(context, 'Rinomina riga', riga.nome);
    if (nome == null || !context.mounted) return;
    await modificaVoce(
      context,
      ref,
      voci,
      voceId,
      (s) => s.rinominaRiga(voceId, riga.id, nome),
    );
  }
}

class _NuovaRigaDialog extends StatefulWidget {
  const _NuovaRigaDialog();

  @override
  State<_NuovaRigaDialog> createState() => _NuovaRigaDialogState();
}

class _NuovaRigaDialogState extends State<_NuovaRigaDialog> {
  final _nome = TextEditingController();
  final _saldo = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _saldo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuova riga'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nome,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        TextField(
          controller: _saldo,
          decoration: const InputDecoration(labelText: 'Saldo'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      TextButton(
        onPressed: () =>
            Navigator.pop(context, (nome: _nome.text, saldo: _saldo.text)),
        child: const Text('Aggiungi'),
      ),
    ],
  );
}

class _RigaRow extends StatelessWidget {
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Row(
      children: [
        Expanded(child: Text(riga.nome)),
        SaldoEditor(saldoCentesimi: riga.saldoCentesimi, onSalva: onSaldo),
        IconButton(
          tooltip: 'Rinomina ${riga.nome}',
          icon: const Icon(Icons.edit),
          onPressed: onRinomina,
        ),
        IconButton(
          tooltip: 'Elimina ${riga.nome}',
          icon: const Icon(Icons.delete),
          onPressed: onElimina,
        ),
      ],
    ),
  );
}
