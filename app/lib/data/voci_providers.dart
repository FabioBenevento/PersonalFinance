import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../domain/voce.dart';
import '../domain/voci_iniziali.dart';
import 'firestore_voci_repository.dart';
import 'inizializzazione_service.dart';
import 'voci_repository.dart';

/// Repository of the signed-in user's voci; overridden with a fake in widget tests.
final vociRepositoryProvider = Provider<VociRepository>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth is! Allowed) throw StateError('Utente non autorizzato');
  return FirestoreVociRepository(auth.uid);
});

final vociProvider = StreamProvider<List<Voce>>(
  (ref) => ref.watch(vociRepositoryProvider).osserva(),
);

/// One-time initial load of the signed-in user's voci; the Situazione waits for it.
final inizializzazioneProvider = FutureProvider<void>((ref) async {
  final service = InizializzazioneService(ref.watch(vociRepositoryProvider));
  await service.inizializzaSeNecessario(vociIniziali);
});
