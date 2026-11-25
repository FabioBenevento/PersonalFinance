@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/firestore_broker_repository.dart';
import 'package:personal_finance/domain/associazioni_broker.dart';
import 'package:personal_finance/domain/voce.dart';

import 'support/firebase_emulator_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseEmulatorHarness harness;
  setUpAll(() async => harness = await FirebaseEmulatorHarness.open());
  tearDownAll(() async => harness.close());

  const liq = Voce.semplice(id: 'liq', nome: 'Liq', gruppo: Gruppo.liquidita);
  const det = Voce.conDettaglio(
    id: 'det',
    nome: 'Det',
    gruppo: Gruppo.investimenti,
  );

  test('BRO-015 associazioni salvate con le regole reali e riviste', () async {
    final repo = FirestoreBrokerRepository(harness.uid, harness.firestore);
    final a1 = associa(
      tutte: {},
      contoId: 'ibkr',
      componente: ComponenteBroker.liquidita,
      voceId: 'liq',
      voci: [liq],
    );
    await repo.salvaAssociazioni('ibkr', a1);
    final lette = await repo.osservaAssociazioni().first;
    expect(lette['ibkr']!.revisione, 1);
    expect(lette['ibkr']!.liquidita, 'liq');
    // Un secondo salvataggio con la stessa revisione base e un conflitto.
    // Sul web l'errore della transazione arriva avvolto: conta l'effetto.
    await expectLater(repo.salvaAssociazioni('ibkr', a1), throwsA(anything));
    final attuale = await harness.firestore
        .doc('users/${harness.uid}/brokerAssociazioni/ibkr')
        .get(const GetOptions(source: Source.server));
    expect(attuale.data()!['revisione'], 1);
    final a2 = associa(
      tutte: lette,
      contoId: 'ibkr',
      componente: ComponenteBroker.investimenti,
      voceId: 'inv',
      voci: [
        liq,
        const Voce.semplice(
          id: 'inv',
          nome: 'Inv',
          gruppo: Gruppo.investimenti,
        ),
      ],
    );
    await repo.salvaAssociazioni('ibkr', a2);
    // Le transazioni scrivono sul server: la cache puo essere indietro.
    final dopo = await harness.firestore
        .doc('users/${harness.uid}/brokerAssociazioni/ibkr')
        .get(const GetOptions(source: Source.server));
    expect(dopo.data(), {
      'revisione': 2,
      'liquidita': 'liq',
      'investimenti': 'inv',
    });
  });

  test('BRO-016 destinazione non valida: nessuna scrittura', () async {
    final repo = FirestoreBrokerRepository(harness.uid, harness.firestore);
    expect(
      () => associa(
        tutte: {},
        contoId: 'degiro',
        componente: ComponenteBroker.investimenti,
        voceId: 'det',
        voci: [det],
      ),
      throwsA(isA<ValidazioneException>()),
    );
    expect(
      (await repo.osservaAssociazioni().first).containsKey('degiro'),
      isFalse,
    );
  });

  test('BRO-022 le regole rifiutano associazioni malformate', () async {
    final ref = harness.firestore.doc(
      'users/${harness.uid}/brokerAssociazioni/x',
    );
    await expectLater(
      ref.set({'revisione': 1, 'liquidita': 5}),
      throwsA(isA<FirebaseException>()),
    );
  });
}
