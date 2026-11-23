import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../data/voci_providers.dart';
import '../domain/importo.dart';
import '../domain/situazione.dart';
import '../domain/voce.dart';
import 'dettaglio_page.dart';
import 'gestione_voci.dart';

class SituazionePage extends ConsumerWidget {
  const SituazionePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(vociProvider);
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('PersonalFinance'),
        ),
        actions: [
          if (voci.value case final v?)
            TextButton(
              onPressed: () => aggiungiVoce(context, ref, v),
              child: const Text('Aggiungi voce'),
            ),
          TextButton(
            onPressed: ref.read(authGatewayProvider).signOut,
            child: const Text('Esci'),
          ),
        ],
      ),
      body: switch (voci) {
        AsyncData(:final value) => _Elenco(Situazione(value)),
        AsyncError() => const Center(
          child: Text('Impossibile leggere le voci'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Elenco extends StatelessWidget {
  const _Elenco(this.situazione);

  final Situazione situazione;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final g in Gruppo.values) ...[
        _Riepilogo(
          nome: nomiGruppo[g]!,
          saldo: situazione.totaleGruppo(g),
          percentuale: situazione.percentualeGruppo(g),
          grassetto: true,
        ),
        for (final v in situazione.voci.where((v) => v.gruppo == g))
          _VoceRow(
            key: ValueKey(v.id),
            voce: v,
            percentuale: situazione.percentualeVoce(v),
          ),
      ],
      _Riepilogo(
        nome: 'Totale',
        saldo: situazione.totale,
        percentuale: null,
        grassetto: true,
      ),
    ],
  );
}

class _Riepilogo extends StatelessWidget {
  const _Riepilogo({
    required this.nome,
    required this.saldo,
    required this.percentuale,
    required this.grassetto,
  });

  final String nome;
  final int saldo;
  final String? percentuale;
  final bool grassetto;

  @override
  Widget build(BuildContext context) {
    final stile = grassetto
        ? const TextStyle(fontWeight: FontWeight.bold)
        : null;
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      title: Text(nome, style: stile),
      trailing: Text(
        [scriviImporto(saldo), ?percentuale].join('  '),
        style: stile,
      ),
    );
  }
}

class _VoceRow extends ConsumerStatefulWidget {
  const _VoceRow({super.key, required this.voce, required this.percentuale});

  final Voce voce;
  final String percentuale;

  @override
  ConsumerState<_VoceRow> createState() => _VoceRowState();
}

class _VoceRowState extends ConsumerState<_VoceRow> {
  late final _controller = TextEditingController(text: _saldo);
  final _focus = FocusNode();

  String get _saldo => scriviImporto(widget.voce.saldoCentesimi);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _salva();
    });
  }

  @override
  void didUpdateWidget(_VoceRow old) {
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
    final messenger = ScaffoldMessenger.of(context);
    final voce = widget.voce;
    final centesimi = leggiImporto(_controller.text);
    if (centesimi == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text(messaggioImportoNonValido)),
      );
    } else if (centesimi != voce.saldoCentesimi) {
      try {
        await ref
            .read(vociRepositoryProvider)
            .salva(
              Voce.semplice(
                id: voce.id,
                nome: voce.nome,
                gruppo: voce.gruppo,
                saldoCentesimi: centesimi,
              ),
            );
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Modifica non salvata, riprova')),
        );
      }
    }
    // Shows the saved value (normalized on success, restored on error).
    if (mounted) _controller.text = _saldo;
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(widget.voce.nome),
    onTap: widget.voce.conDettaglio
        ? () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DettaglioPage(voceId: widget.voce.id),
            ),
          )
        : null,
    trailing: SizedBox(
      width: 220,
      child: Row(
        children: [
          Expanded(
            child: widget.voce.conDettaglio
                ? Text(
                    scriviImporto(widget.voce.saldoCentesimi),
                    textAlign: TextAlign.end,
                  )
                : TextField(
                    controller: _controller,
                    focusNode: _focus,
                    textAlign: TextAlign.end,
                    onSubmitted: (_) => _salva(),
                    decoration: const InputDecoration.collapsed(hintText: ''),
                  ),
          ),
          const SizedBox(width: 8),
          Text(widget.percentuale),
          PopupMenuButton<String>(
            tooltip: 'Azioni ${widget.voce.nome}',
            onSelected: (azione) {
              final voci = ref.read(vociProvider).value ?? const [];
              switch (azione) {
                case 'rinomina':
                  rinominaVoce(context, ref, voci, widget.voce);
                case 'sposta':
                  spostaVoce(context, ref, voci, widget.voce);
                case 'elimina':
                  eliminaVoce(context, ref, widget.voce);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rinomina', child: Text('Rinomina')),
              PopupMenuItem(value: 'sposta', child: Text('Sposta')),
              PopupMenuItem(value: 'elimina', child: Text('Elimina')),
            ],
          ),
        ],
      ),
    ),
  );
}
