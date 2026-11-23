import '../domain/voce.dart';

/// Seam of persistence for voci, replaced with an in-memory fake in tests.
abstract class VociRepository {
  /// Voci ordered by group, then by position in the group.
  Stream<List<Voce>> osserva();

  /// Creates or replaces a voce; a new (or moved) voce goes last in its group.
  /// Ids of the voci with writes not yet confirmed by the server (offline queue).
  Stream<Set<String>> osservaInAttesa();

  /// A new unique id for a voce or a riga, independent of the clock.
  String nuovoId();

  Future<void> salva(Voce voce);

  Future<void> elimina(String id);

  /// Whether the user's initial load was already done.
  Future<bool> inizializzato();

  /// Atomically writes [iniziali] and sets the initialized flag.
  Future<void> scriviIniziali(List<Voce> iniziali);
}
