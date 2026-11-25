@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/firestore_broker_repository.dart';
import 'package:personal_finance/data/voce_mapper.dart';
import 'package:personal_finance/domain/associazioni_broker.dart';
import 'package:personal_finance/domain/conferma_broker.dart';
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

  group('conferma saldi', () {
    var n = 0;
    late String liqId, invId, altraId, conto, op;
    late FirestoreBrokerRepository repo;
    late ConfermaBroker conferma;
    late Voce liqV, invV;

    String p(String x) => 'users/${harness.uid}/$x';
    Future<Map<String, dynamic>?> leggi(String x) async =>
        (await harness.firestore
                .doc(p(x))
                .get(const GetOptions(source: Source.server)))
            .data();
    Future<int> saldo(String id) async =>
        (await leggi('voci/$id'))!['saldoCentesimi'] as int;
    Future<bool> ricevuta() async =>
        (await harness.firestore
                .doc(p('brokerApplicazioni/$op'))
                .get(const GetOptions(source: Source.server)))
            .exists;

    setUp(() async {
      n++;
      liqId = 'liq$n';
      invId = 'inv$n';
      altraId = 'altra$n';
      conto = 'c$n';
      op = 'op$n';
      repo = FirestoreBrokerRepository(harness.uid, harness.firestore);
      liqV = Voce.semplice(
        id: liqId,
        nome: 'Liq',
        gruppo: Gruppo.liquidita,
        saldoCentesimi: 1000,
      );
      invV = Voce.semplice(
        id: invId,
        nome: 'Inv',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.depositoTitoli,
        saldoCentesimi: 2000,
      );
      final altra = Voce.semplice(
        id: altraId,
        nome: 'Altra',
        gruppo: Gruppo.liquidita,
        saldoCentesimi: 5,
      );
      var ordine = 0;
      for (final v in [liqV, invV, altra]) {
        await harness.firestore
            .doc(p('voci/${v.id}'))
            .set(voceToMap(v, ordine++));
      }
      await harness.scriviRemoto(p('brokerStato/snaptrade'), {
        'attivaId': {'stringValue': 'g1'},
      });
      await repo.salvaAssociazioni(
        conto,
        AssociazioniConto(revisione: 1, liquidita: liqId, investimenti: invId),
      );
      conferma = ConfermaBroker(
        operazioneId: op,
        rilevazioneId: 'g1',
        associazioni: {
          conto: AssociazioniConto(
            revisione: 1,
            liquidita: liqId,
            investimenti: invId,
          ),
        },
        saldi: [
          SaldoDaConfermare(
            contoId: conto,
            componente: ComponenteBroker.liquidita,
            voce: liqV,
            proposto: 1500,
          ),
          SaldoDaConfermare(
            contoId: conto,
            componente: ComponenteBroker.investimenti,
            voce: invV,
            proposto: 2500,
          ),
        ],
      );
    });

    Future<void> nessunaScrittura() async {
      expect(await saldo(liqId), 1000);
      expect(await saldo(invId), isNot(2500));
      expect(await ricevuta(), isFalse);
    }

    test(
      'SIT-BRO-002 applica solo i saldi selezionati e la ricevuta',
      () async {
        final soloLiq = ConfermaBroker(
          operazioneId: op,
          rilevazioneId: 'g1',
          associazioni: conferma.associazioni,
          saldi: [conferma.saldi.first],
        );
        final prima = await leggi('voci/$liqId');
        await repo.confermaSaldi(soloLiq);
        expect(await saldo(liqId), 1500);
        expect(await saldo(invId), 2000);
        expect(await saldo(altraId), 5);
        expect(
          {...(await leggi('voci/$liqId'))!}..remove('saldoCentesimi'),
          {...prima!}..remove('saldoCentesimi'),
        );
        final r = (await leggi('brokerApplicazioni/$op'))!;
        expect(r['rilevazione'], 'g1');
        expect(r['conti'], {
          conto: {
            'liquidita': {'voce': liqId, 'saldoCentesimi': 1500},
          },
        });
        expect((await leggi('voci/$invId'))!['categoria'], 'depositoTitoli');
      },
    );

    test('SIT-BRO-002 conferma di piu saldi insieme', () async {
      await repo.confermaSaldi(conferma);
      expect(await saldo(liqId), 1500);
      expect(await saldo(invId), 2500);
      expect(await ricevuta(), isTrue);
    });

    test(
      'SIT-BRO-003 SIT-BRO-002 un saldo cambiato blocca tutta la selezione',
      () async {
        await harness.impostaSaldoRemoto(invId, 2222);
        await expectLater(
          repo.confermaSaldi(conferma),
          throwsA(isA<ConflittoConfermaException>()),
        );
        expect(await saldo(liqId), 1000);
        expect(await saldo(invId), 2222);
        expect(await ricevuta(), isFalse);
      },
    );

    test('SIT-BRO-003 rilevazione attiva cambiata', () async {
      await harness.scriviRemoto(p('brokerStato/snaptrade'), {
        'attivaId': {'stringValue': 'g2'},
      });
      await expectLater(
        repo.confermaSaldi(conferma),
        throwsA(isA<ConflittoConfermaException>()),
      );
      await nessunaScrittura();
    });

    test('SIT-BRO-003 associazione cambiata', () async {
      await repo.salvaAssociazioni(
        conto,
        AssociazioniConto(
          revisione: 2,
          liquidita: altraId,
          investimenti: invId,
        ),
      );
      await expectLater(
        repo.confermaSaldi(conferma),
        throwsA(isA<ConflittoConfermaException>()),
      );
      await nessunaScrittura();
    });

    test('SIT-BRO-003 voce rinominata e poi spostata di gruppo', () async {
      await harness.scriviCampiRemoti(liqId, {
        'nome': {'stringValue': 'Altro nome'},
      });
      await expectLater(
        repo.confermaSaldi(conferma),
        throwsA(isA<ConflittoConfermaException>()),
      );
      await harness.scriviCampiRemoti(liqId, {
        'nome': {'stringValue': 'Liq'},
        'gruppo': {'stringValue': 'investimenti'},
      });
      await expectLater(
        repo.confermaSaldi(conferma),
        throwsA(isA<ConflittoConfermaException>()),
      );
      await nessunaScrittura();
    });

    test(
      'SIT-BRO-003 voce eliminata: nessuna scrittura, nessuna ricreazione',
      () async {
        await harness.eliminaRemoto(p('voci/$invId'));
        await expectLater(
          repo.confermaSaldi(conferma),
          throwsA(isA<ConflittoConfermaException>()),
        );
        expect(await leggi('voci/$invId'), isNull);
        expect(await saldo(liqId), 1000);
        expect(await ricevuta(), isFalse);
      },
    );

    test(
      'SIT-BRO-004 doppio invio, anche concorrente: una sola applicazione',
      () async {
        await Future.wait([
          repo.confermaSaldi(conferma),
          repo.confermaSaldi(conferma),
        ]);
        expect(await saldo(liqId), 1500);
        // Ritrasmissione dopo una modifica manuale: non riapplica.
        await harness.impostaSaldoRemoto(liqId, 777);
        await repo.confermaSaldi(conferma);
        expect(await saldo(liqId), 777);
        expect(await saldo(invId), 2500);
      },
    );

    test('SIT-BRO-005 senza server la conferma fallisce e non viene accodata', () async {
      // Il plugin web ignora disableNetwork per le transazioni: si simula
      // l'assenza di rete con un'istanza che punta a un server irraggiungibile.
      final app = await Firebase.initializeApp(
        name: 'offline$n',
        options: harness.app.options,
      );
      final db = FirebaseFirestore.instanceFor(app: app)
        ..useFirestoreEmulator('127.0.0.1', 1);
      try {
        await expectLater(
          FirestoreBrokerRepository(
            harness.uid,
            db,
          ).confermaSaldi(conferma).timeout(const Duration(seconds: 60)),
          throwsA(anything),
        );
      } finally {
        await db.terminate();
        await app.delete();
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await saldo(liqId), 1000);
      expect(await saldo(invId), 2000);
      expect(await ricevuta(), isFalse);
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
