import '../domain/voce.dart';

/// Seam of persistence for voci, replaced with an in-memory fake in tests.
abstract class VociRepository {
  /// Voci ordered by group, then by position in the group.
  Stream<List<Voce>> osserva();

  /// Creates or replaces a voce; a new (or moved) voce goes last in its group.
  Future<void> salva(Voce voce);

  Future<void> elimina(String id);

  /// Writes [iniziali] atomically, only if the user has never been initialized.
  /// Returns whether it wrote.
  Future<bool> inizializzaSeNecessario(List<Voce> iniziali);
}
