import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';
import '../domain/conferma_broker.dart';
import 'broker_repository.dart';
import 'firestore_broker_repository.dart';
import 'operazioni_coordinator.dart';
import 'voci_providers.dart';

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

/// Conferma dei saldi coordinata con le altre scritture: una fotografia in
/// acquisizione la rifiuta ([ModificheBloccateException]) e una conferma gia
/// avviata la fa attendere. [repositoryAnteprima] e quello con cui e stata
/// aperta l'anteprima: se l'utente e cambiato non e piu applicabile.
final confermaBrokerProvider =
    Provider<
      Future<bool> Function(
        BrokerRepository repositoryAnteprima,
        ConfermaBroker,
      )
    >(
      (ref) =>
          (repositoryAnteprima, conferma) async =>
              ref.read(operazioniCoordinatorProvider).modifica(() async {
                if (!identical(
                  ref.read(brokerRepositoryProvider),
                  repositoryAnteprima,
                )) {
                  throw StateError('Anteprima di un altro utente');
                }
                return repositoryAnteprima.confermaSaldi(conferma);
              }),
    );
