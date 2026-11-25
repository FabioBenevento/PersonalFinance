import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../domain/fotografia_mensile.dart';
import 'firestore_fotografie_repository.dart';
import 'fotografie_repository.dart';
import 'fotografie_service.dart';

final fotografieRepositoryProvider = Provider<FotografieRepository>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth is! Allowed) throw StateError('Utente non autorizzato');
  return FirestoreFotografieRepository(auth.uid);
});

// Firestore reconnects on its own: Riverpod's automatic retry would only keep
// the page loading for ~40 s before showing the error.
final fotografieProvider = StreamProvider<List<FotografiaMensile>>(
  (ref) => ref.watch(fotografieRepositoryProvider).osserva(),
  retry: (_, _) => null,
);

final fotografieServiceProvider = Provider<FotografieService>(
  (ref) => FotografieService(ref.watch(fotografieRepositoryProvider)),
);

final oggiProvider = Provider<DateTime Function()>((ref) => DateTime.now);
