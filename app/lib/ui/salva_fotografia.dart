import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fotografie_providers.dart';
import '../data/fotografie_repository.dart';
import '../data/operazioni_coordinator.dart';
import '../data/voci_providers.dart';
import '../domain/fotografia_mensile.dart';
import '../domain/mese.dart';
import '../domain/voce.dart';
import 'etichette.dart';

class SalvaFotografiaButton extends ConsumerStatefulWidget {
  const SalvaFotografiaButton({super.key});

  @override
  ConsumerState<SalvaFotografiaButton> createState() =>
      _SalvaFotografiaButtonState();
}

class _SalvaFotografiaButtonState extends ConsumerState<SalvaFotografiaButton> {
  bool _inCorso = false;

  Future<void> _salva() async {
    if (_inCorso) return;
    setState(() => _inCorso = true);
    final oggi = ref.read(oggiProvider)();
    final mese = await showDialog<Mese>(
      context: context,
      builder: (_) => _MeseDialog(oggi),
    );
    if (mese == null || !mounted) {
      if (mounted) setState(() => _inCorso = false);
      return;
    }
    String messaggio;
    OperazioneLease? lease;
    try {
      lease = await ref.read(operazioniCoordinatorProvider).blocca();
      final service = ref.read(fotografieServiceProvider);
      FotografiaMensile? esistente;
      try {
        await service.salvaNuovo(
          mese,
          oggi: oggi,
          verificaOperazione: lease.verifica,
        );
      } on ConflittoFotografiaException catch (e) {
        esistente = e.attuale;
      }
      if (!mounted) return;
      var conflitto = false;
      while (esistente != null && mounted) {
        final attesa = esistente;
        if (!mounted) return;
        final confermato = await _confermaSostituzione(
          context,
          mese,
          conflitto: conflitto,
        );
        if (!confermato || !mounted) break;
        try {
          lease.verifica();
          await service.sostituisci(
            mese,
            attesa,
            oggi: oggi,
            verificaOperazione: lease.verifica,
          );
          esistente = null;
        } on ConflittoFotografiaException catch (e) {
          esistente = e.attuale;
          conflitto = true;
        }
      }
      if (esistente != null) {
        if (!mounted) return;
        setState(() => _inCorso = false);
        return;
      }
      messaggio = 'Fotografia salvata';
    } on ConflittoFotografiaException {
      messaggio = 'Esiste già una fotografia per ${nomeMese(mese)}';
    } on ClassificazioneIncompletaException {
      messaggio =
          'Fotografia non salvata: classifica prima tutte le voci degli '
          'Investimenti. Le fotografie già salvate non sono state modificate.';
    } catch (_) {
      messaggio = 'Fotografia non salvata, riprova';
    } finally {
      lease?.dispose();
    }
    if (!mounted) return;
    setState(() => _inCorso = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(messaggio)));
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: _inCorso ? 'Salvataggio fotografia in corso' : 'Salva fotografia',
    child: FilledButton.icon(
      onPressed: _inCorso ? null : _salva,
      icon: Icon(_inCorso ? Icons.hourglass_top : Icons.add_a_photo_outlined),
      label: Text(_inCorso ? 'Salvataggio in corso' : 'Salva fotografia'),
    ),
  );
}

Future<bool> _confermaSostituzione(
  BuildContext context,
  Mese mese, {
  required bool conflitto,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          conflitto
              ? 'La fotografia è cambiata. Confermi la sostituzione di ${nomeMese(mese)}?'
              : 'Sostituire la fotografia di ${nomeMese(mese)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sostituisci'),
          ),
        ],
      ),
    ) ??
    false;

class _MeseDialog extends StatefulWidget {
  const _MeseDialog(this.oggi);
  final DateTime oggi;

  @override
  State<_MeseDialog> createState() => _MeseDialogState();
}

class _MeseDialogState extends State<_MeseDialog> {
  late final _anno = TextEditingController(text: '${widget.oggi.year}');
  late int _mese = widget.oggi.month;
  String? _errore;

  @override
  void dispose() {
    _anno.dispose();
    super.dispose();
  }

  void _conferma() {
    try {
      final mese = Mese(int.tryParse(_anno.text) ?? 0, _mese);
      mese.valida(widget.oggi);
      Navigator.pop(context, mese);
    } on ValidazioneException catch (e) {
      setState(() => _errore = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Salva fotografia'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _anno,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Anno'),
          ),
          DropdownButtonFormField<int>(
            initialValue: _mese,
            decoration: const InputDecoration(labelText: 'Mese'),
            items: [
              for (var i = 1; i <= 12; i++)
                DropdownMenuItem(value: i, child: Text(nomiMesi[i - 1])),
            ],
            onChanged: (value) => setState(() => _mese = value!),
          ),
          if (_errore != null) Text(_errore!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      TextButton(onPressed: _conferma, child: const Text('Salva')),
    ],
  );
}
