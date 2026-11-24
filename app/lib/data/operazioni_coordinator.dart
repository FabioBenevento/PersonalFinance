import 'dart:async';

class ModificheBloccateException implements Exception {}

class OperazioniCoordinator {
  OperazioniCoordinator({this.onBloccoCambiato});

  final void Function(bool bloccato)? onBloccoCambiato;
  final _pendenti = <Future<void>>{};
  var _bloccato = false;
  var _generazione = 0;
  Object? _erroreDuranteAttesa;

  bool get bloccato => _bloccato;

  Future<T> modifica<T>(Future<T> Function() operazione) {
    if (_bloccato) throw ModificheBloccateException();
    final completamento = Completer<void>();
    _pendenti.add(completamento.future);
    return _esegui(operazione, completamento);
  }

  Future<T> _esegui<T>(
    Future<T> Function() operazione,
    Completer<void> completamento,
  ) async {
    try {
      return await operazione();
    } catch (errore) {
      if (_bloccato) _erroreDuranteAttesa ??= errore;
      rethrow;
    } finally {
      _pendenti.remove(completamento.future);
      completamento.complete();
    }
  }

  Future<OperazioneLease> blocca() async {
    if (_bloccato) throw ModificheBloccateException();
    _bloccato = true;
    _erroreDuranteAttesa = null;
    onBloccoCambiato?.call(true);
    final generazione = _generazione;
    try {
      await Future.wait(_pendenti.toList());
      if (_erroreDuranteAttesa case final errore?) throw errore;
      return OperazioneLease(this, generazione);
    } catch (_) {
      sblocca(generazione);
      rethrow;
    }
  }

  void invalida() {
    _generazione++;
    _bloccato = false;
    onBloccoCambiato?.call(false);
  }

  void sblocca(int generazione) {
    if (_generazione == generazione && _bloccato) {
      _bloccato = false;
      onBloccoCambiato?.call(false);
    }
  }

  bool valida(int generazione) => _bloccato && _generazione == generazione;
}

class OperazioneLease {
  OperazioneLease(this._coordinator, this._generazione);
  final OperazioniCoordinator _coordinator;
  final int _generazione;

  bool get valida => _coordinator.valida(_generazione);

  void verifica() {
    if (!valida) throw StateError('Operazione di acquisizione invalidata');
  }

  void dispose() => _coordinator.sblocca(_generazione);
}
