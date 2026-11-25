import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';
import 'broker_repository.dart';
import 'firestore_broker_repository.dart';

final brokerRepositoryProvider = Provider<BrokerRepository>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth is! Allowed) throw StateError('Utente non autorizzato');
  return FirestoreBrokerRepository(auth.uid);
});

// Come per le fotografie: i tentativi automatici di Riverpod nasconderebbero
// l'errore dietro un caricamento prolungato.
final rilevazioneBrokerProvider = StreamProvider<RilevazioneBroker?>(
  (ref) => ref.watch(brokerRepositoryProvider).osservaAttiva(),
  retry: (_, _) => null,
);

final associazioniBrokerProvider =
    StreamProvider<Map<String, AssociazioniConto>>(
      (ref) => ref.watch(brokerRepositoryProvider).osservaAssociazioni(),
    );
