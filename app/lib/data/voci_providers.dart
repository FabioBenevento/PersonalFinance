import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../domain/voce.dart';
import '../domain/voci_iniziali.dart';
import 'firestore_voci_repository.dart';
import 'inizializzazione_service.dart';
import 'operazioni_coordinator.dart';
import 'voci_repository.dart';

/// Repository of the signed-in user's voci; overridden with a fake in widget tests.
final vociRepositoryProvider = Provider<VociRepository>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth is! Allowed) throw StateError('Utente non autorizzato');
  return FirestoreVociRepository(auth.uid);
});

final operazioniBloccateProvider = NotifierProvider<_BloccoNotifier, bool>(
  _BloccoNotifier.new,
);

class _BloccoNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void aggiorna(bool value) => state = value;
}

final operazioniCoordinatorProvider = Provider<OperazioniCoordinator>((ref) {
  final coordinator = OperazioniCoordinator(
    onBloccoCambiato: (bloccato) =>
        ref.read(operazioniBloccateProvider.notifier).aggiorna(bloccato),
  );
  String? uid(AuthState? state) => state is Allowed ? state.uid : null;
  ref.listen(authStateProvider, (prima, dopo) {
    if (uid(prima?.value) != uid(dopo.value)) coordinator.invalida();
  });
  return coordinator;
});

final vociProvider = StreamProvider<List<Voce>>(
  (ref) => ref.watch(vociRepositoryProvider).osserva(),
  retry: (_, _) => null,
);

/// Ids of the voci waiting for the server to confirm a write.
final vociInAttesaProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(vociRepositoryProvider).osservaInAttesa(),
  retry: (_, _) => null,
);

/// One-time initial load of the signed-in user's voci; the Situazione waits for it.
final inizializzazioneProvider = FutureProvider<void>(retry: (_, _) => null, (
  ref,
) async {
  final service = InizializzazioneService(ref.watch(vociRepositoryProvider));
  await service.inizializzaSeNecessario(vociIniziali);
});

/// Classification of the initial voci saved before the categorie existed;
/// coordinated with the other writes, retried by invalidating it.
final migrazioneCategorieProvider = FutureProvider<void>(
  retry: (_, _) => null,
  (ref) async {
    await ref.watch(inizializzazioneProvider.future);
    final service = InizializzazioneService(ref.watch(vociRepositoryProvider));
    await ref
        .read(operazioniCoordinatorProvider)
        .modifica(service.migraCategorie);
  },
);
