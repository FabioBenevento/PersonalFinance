import '../domain/voce.dart';
import '../domain/voci_iniziali.dart';
import 'voci_repository.dart';

/// Loads the initial voci once per user: the rule lives here, not in the repository.
class InizializzazioneService {
  InizializzazioneService(this._repo);

  final VociRepository _repo;

  /// Writes [iniziali] (and the flag) only if the user was never initialized.
  /// Returns whether it wrote.
  Future<bool> inizializzaSeNecessario(List<Voce> iniziali) async {
    if (await _repo.inizializzato()) return false;
    await _repo.scriviIniziali(iniziali);
    return true;
  }

  /// Classifies the initial voci still without categoria, by id only.
  /// Idempotent: a categoria chosen meanwhile, a move or a deletion wins.
  Future<void> migraCategorie() =>
      _repo.classificaSeMancanti(categorieInizialiInvestimenti);
}
