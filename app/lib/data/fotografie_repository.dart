import '../domain/fotografia_mensile.dart';
import '../domain/mese.dart';
import '../domain/voce.dart';

class ConflittoFotografiaException implements Exception {
  const ConflittoFotografiaException(this.attuale);
  final FotografiaMensile attuale;
}

/// At least one Investimenti voce has no categoria: no fotografia is saved.
class ClassificazioneIncompletaException implements Exception {
  const ClassificazioneIncompletaException();
}

abstract interface class FotografieRepository {
  Stream<List<FotografiaMensile>> osserva();
  Future<FotografiaMensile?> leggi(Mese mese);
  Future<void> attendiSincronizzazione();
  Future<List<Voce>> acquisisciVoci();
  Future<FotografiaMensile> crea(FotografiaMensile fotografia);
  Future<FotografiaMensile> sostituisci(
    FotografiaMensile fotografia,
    FotografiaMensile attesa,
  );
}
