import 'package:flutter/material.dart';

import '../domain/importo.dart';

const larghezzaSaldo = 140.0;

/// Campo di un importo modificabile: salva all'invio o alla perdita del fuoco
/// e mostra sempre il valore salvato (normalizzato, o ripristinato in caso di errore).
class SaldoEditor extends StatefulWidget {
  const SaldoEditor({
    super.key,
    required this.saldoCentesimi,
    required this.onSalva,
    this.enabled = true,
  });

  final int saldoCentesimi;
  final Future<void> Function(int centesimi) onSalva;
  final bool enabled;

  @override
  State<SaldoEditor> createState() => _SaldoEditorState();
}

class _SaldoEditorState extends State<SaldoEditor> {
  late final _controller = TextEditingController(text: _saldo);
  final _focus = FocusNode();

  String get _saldo => scriviImporto(widget.saldoCentesimi);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _salva();
    });
  }

  @override
  void didUpdateWidget(SaldoEditor old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus) _controller.text = _saldo;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void>? _salvataggio;

  Future<void> _salva() {
    final attivo = _salvataggio;
    if (attivo != null) return attivo;
    final salvataggio = _salvaUnaVolta();
    _salvataggio = salvataggio;
    return salvataggio.whenComplete(() {
      if (identical(_salvataggio, salvataggio)) _salvataggio = null;
    });
  }

  Future<void> _salvaUnaVolta() async {
    final centesimi = leggiImporto(_controller.text);
    if (centesimi == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(messaggioImportoNonValido)));
    } else if (centesimi != widget.saldoCentesimi) {
      await widget.onSalva(centesimi);
    }
    if (mounted) _controller.text = _saldo;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: larghezzaSaldo,
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      textAlign: TextAlign.end,
      onSubmitted: (_) => _salva(),
      decoration: const InputDecoration.collapsed(hintText: ''),
    ),
  );
}
