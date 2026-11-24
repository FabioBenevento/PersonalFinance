import '../domain/fotografia_mensile.dart';
import '../domain/mese.dart';
import '../domain/situazione.dart';
import '../domain/voce.dart';
import 'fotografie_repository.dart';

class FotografieService {
  FotografieService(this._repo);
  final FotografieRepository _repo;

  Future<FotografiaMensile> salvaNuovo(
    Mese mese, {
    required DateTime oggi,
    void Function()? verificaOperazione,
  }) async {
    mese.valida(oggi);
    // La lettura server verifica la connessione prima dell'attesa delle scritture.
    final attuale = await _repo.leggi(mese);
    if (attuale != null) throw ConflittoFotografiaException(attuale);
    await _repo.attendiSincronizzazione();
    final voci = await _repo.acquisisciVoci();
    _richiediClassificazione(voci);
    verificaOperazione?.call();
    return _repo.crea(FotografiaMensile(mese: mese, voci: voci));
  }

  Future<FotografiaMensile> sostituisci(
    Mese mese,
    FotografiaMensile attesa, {
    required DateTime oggi,
    void Function()? verificaOperazione,
  }) async {
    mese.valida(oggi);
    await _repo.attendiSincronizzazione();
    final voci = await _repo.acquisisciVoci();
    _richiediClassificazione(voci);
    final attuale = await _repo.leggi(mese);
    if (attuale == null || attuale.revisione != attesa.revisione) {
      throw ConflittoFotografiaException(attuale ?? attesa);
    }
    verificaOperazione?.call();
    return _repo.sostituisci(FotografiaMensile(mese: mese, voci: voci), attesa);
  }

  // Controllo sui dati server appena acquisiti, prima di qualsiasi scrittura.
  void _richiediClassificazione(List<Voce> voci) {
    if (!Situazione(voci).classificazioneCompleta) {
      throw const ClassificazioneIncompletaException();
    }
  }
}
