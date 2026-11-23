import '../domain/fotografia_mensile.dart';
import '../domain/mese.dart';
import 'fotografie_repository.dart';

class FotografieService {
  FotografieService(this._repo);
  final FotografieRepository _repo;

  Future<FotografiaMensile> salvaNuovo(
    Mese mese, {
    required DateTime oggi,
  }) async {
    mese.valida(oggi);
    // La lettura server verifica la connessione prima dell'attesa delle scritture.
    final attuale = await _repo.leggi(mese);
    if (attuale != null) throw ConflittoFotografiaException(attuale);
    await _repo.attendiSincronizzazione();
    final voci = await _repo.acquisisciVoci();
    return _repo.crea(FotografiaMensile(mese: mese, voci: voci));
  }
}
