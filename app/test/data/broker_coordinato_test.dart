import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/broker_providers.dart';
import 'package:personal_finance/data/operazioni_coordinator.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/domain/conferma_broker.dart';

import 'fake_broker_repository.dart';

class _Gateway implements AuthGateway {
  final uid = StreamController<String?>();
  @override
  Stream<String?> uidChanges() => uid.stream;
  @override
  Future<bool> isAllowed(String uid) async => true;
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}

class _Lento extends FakeBrokerRepository {
  final gate = Completer<void>();
  @override
  Future<bool> confermaSaldi(ConfermaBroker c) async {
    await gate.future;
    return super.confermaSaldi(c);
  }
}

const _conferma = ConfermaBroker(
  operazioneId: 'op',
  rilevazioneId: 'r',
  associazioni: {},
  saldi: [],
);

void main() {
  final repos = <String, FakeBrokerRepository>{};
  late _Gateway gateway;
  late ProviderContainer container;

  Future<void> accedi(String uid) async {
    gateway.uid.add(uid);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    repos.clear();
    gateway = _Gateway();
    container = ProviderContainer(
      overrides: [
        authGatewayProvider.overrideWithValue(gateway),
        brokerRepositoryProvider.overrideWith((ref) {
          final a = ref.watch(authStateProvider).value;
          if (a is! Allowed) throw StateError('Utente non autorizzato');
          return repos.putIfAbsent(a.uid, _Lento.new);
        }),
      ],
    );
    container.listen(authStateProvider, (_, _) {});
    addTearDown(container.dispose);
    addTearDown(gateway.uid.close);
  });

  test('SIT-BRO-006 la fotografia attende la conferma e la esclude se avviata prima', () async {
    await accedi('u1');
    final repo = container.read(brokerRepositoryProvider) as _Lento;
    final coordinator = container.read(operazioniCoordinatorProvider);
    final conferma = container.read(confermaBrokerProvider)(repo, _conferma);
    await Future<void>.delayed(Duration.zero);

    var acquisizionePronta = false;
    final lease = coordinator.blocca().then((l) {
      acquisizionePronta = true;
      return l;
    });
    await Future<void>.delayed(Duration.zero);
    expect(acquisizionePronta, isFalse);
    // Nuove conferme durante l'acquisizione sono rifiutate senza scritture.
    await expectLater(
      container.read(confermaBrokerProvider)(repo, _conferma),
      throwsA(isA<ModificheBloccateException>()),
    );

    repo.gate.complete();
    await conferma;
    (await lease).dispose();
    expect(repo.conferme, hasLength(1));
  });

  test('SIT-BRO-005 proposta del precedente utente non applicabile', () async {
    await accedi('u1');
    final precedente = container.read(brokerRepositoryProvider) as _Lento;
    await accedi('u2');
    final corrente = container.read(brokerRepositoryProvider) as _Lento;
    precedente.gate.complete();
    corrente.gate.complete();

    await expectLater(
      container.read(confermaBrokerProvider)(precedente, _conferma),
      throwsStateError,
    );
    expect(precedente.conferme, isEmpty);
    expect(corrente.conferme, isEmpty);
  });

  test(
    'BRO-002 integrazione disattivata: la modifica manuale resta utilizzabile',
    () async {
      await accedi('u1');
      final repo = container.read(brokerRepositoryProvider);
      var modificata = false;
      await container.read(operazioniCoordinatorProvider).modifica(() async {
        modificata = true;
      });
      expect(modificata, isTrue);
      expect((repo as FakeBrokerRepository).conferme, isEmpty);
    },
  );
}
