import '../domain/fotografia_mensile.dart';
import '../domain/mese.dart';
import '../domain/voce.dart';

class ConflittoFotografiaException implements Exception {
  const ConflittoFotografiaException(this.attuale);
  final FotografiaMensile attuale;
}

abstract interface class FotografieRepository {
  Stream<List<FotografiaMensile>> osserva();
  Future<FotografiaMensile?> leggi(Mese mese);
  Future<void> attendiSincronizzazione();
  Future<List<Voce>> acquisisciVoci();
  Future<FotografiaMensile> crea(FotografiaMensile fotografia);
}
