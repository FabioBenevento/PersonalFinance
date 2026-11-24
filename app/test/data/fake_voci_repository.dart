import 'dart:async';

import 'package:personal_finance/data/voci_repository.dart';
import 'package:personal_finance/domain/voce.dart';

/// In-memory [VociRepository]; set [errore] to make writes fail.
class FakeVociRepository implements VociRepository {
  FakeVociRepository([List<Voce> voci = const []])
    : _inizializzato = voci.isNotEmpty {
    for (final v in voci) {
      _voci.add(v);
    }
  }

  final _voci = <Voce>[];
  final _changes = StreamController<void>.broadcast();
  bool _inizializzato;
  Object? errore;

  /// Called with every voce passed to [salva].
  void Function(Voce)? suSalva;
  Future<void>? primaDiSalva;
  Future<void>? primaDiEliminare;
  final _inAttesa = StreamController<Set<String>>.broadcast();
  Set<String> _attesa = {};
  var _contatore = 0;

  /// Simulates the server (not) confirming the writes of the given voci.
  void impostaInAttesa(Set<String> ids) {
    _attesa = ids;
    _inAttesa.add(ids);
  }

  @override
  Stream<Set<String>> osservaInAttesa() async* {
    yield _attesa;
    yield* _inAttesa.stream;
  }

  @override
  String nuovoId() => 'id${_contatore++}';

  List<Voce> get _ordinate => [
    for (final g in Gruppo.values) ..._voci.where((v) => v.gruppo == g),
  ];

  @override
  Stream<List<Voce>> osserva() async* {
    yield _ordinate;
    await for (final _ in _changes.stream) {
      yield _ordinate;
    }
  }

  void _scrivi(void Function() f) {
    if (errore != null) throw errore!;
    f();
    _changes.add(null);
  }

  @override
  Future<void> salva(Voce voce) async {
    await primaDiSalva;
    _scrivi(() {
      suSalva?.call(voce);
      final i = _voci.indexWhere((v) => v.id == voce.id);
      if (i >= 0 && _voci[i].gruppo == voce.gruppo) {
        _voci[i] = voce;
      } else {
        if (i >= 0) _voci.removeAt(i);
        _voci.add(voce);
      }
    });
  }

  @override
  Future<void> elimina(String id) async {
    await primaDiEliminare;
    _scrivi(() => _voci.removeWhere((v) => v.id == id));
  }

  @override
  Future<bool> inizializzato() async => _inizializzato;

  @override
  Future<void> scriviIniziali(List<Voce> iniziali) async => _scrivi(() {
    _voci.addAll(iniziali);
    _inizializzato = true;
  });
}
