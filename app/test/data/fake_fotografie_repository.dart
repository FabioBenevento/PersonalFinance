import 'dart:async';

import 'package:personal_finance/data/fotografie_repository.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';

class FakeFotografieRepository implements FotografieRepository {
  FakeFotografieRepository([this.vociServer = const []]);
  List<Voce> vociServer;
  final fotografie = <String, FotografiaMensile>{};
  final chiamate = <String>[];
  final _changes = StreamController<void>.broadcast();
  Future<void>? sincronizzazione;
  Object? errore;
  void Function()? primaDiCreare;

  void _check() {
    if (errore != null) throw errore!;
  }

  @override
  Stream<List<FotografiaMensile>> osserva() async* {
    List<FotografiaMensile> ordinate() =>
        fotografie.values.toList()..sort((a, b) => b.mese.compareTo(a.mese));
    _check();
    yield ordinate();
    await for (final _ in _changes.stream) {
      _check();
      yield ordinate();
    }
  }

  @override
  Future<FotografiaMensile?> leggi(Mese mese) async {
    chiamate.add('leggi');
    _check();
    return fotografie[mese.id];
  }

  @override
  Future<void> attendiSincronizzazione() async {
    chiamate.add('sincronizza');
    _check();
    await sincronizzazione;
  }

  @override
  Future<List<Voce>> acquisisciVoci() async {
    chiamate.add('acquisisci');
    _check();
    return vociServer;
  }

  @override
  Future<FotografiaMensile> crea(FotografiaMensile fotografia) async {
    chiamate.add('crea');
    _check();
    primaDiCreare?.call();
    final attuale = fotografie[fotografia.mese.id];
    if (attuale != null) throw ConflittoFotografiaException(attuale);
    final salvata = FotografiaMensile(
      mese: fotografia.mese,
      voci: fotografia.voci,
      salvataIl: DateTime.utc(2026, 11, 23),
    );
    fotografie[fotografia.mese.id] = salvata;
    _changes.add(null);
    return salvata;
  }

  Future<void> close() => _changes.close();
}
