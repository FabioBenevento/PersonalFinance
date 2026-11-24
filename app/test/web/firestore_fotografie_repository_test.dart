@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/firestore_fotografie_repository.dart';
import 'package:personal_finance/data/fotografie_service.dart';
import 'package:personal_finance/data/fotografie_repository.dart';
import 'package:personal_finance/data/firestore_voci_repository.dart';
import 'package:personal_finance/data/operazioni_coordinator.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';

import 'support/firebase_emulator_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseEmulatorHarness harness;
  setUpAll(() async => harness = await FirebaseEmulatorHarness.open());
  tearDownAll(() async => harness.close());

  test('FOT-011 FOT-005 adattatore salva saldi server diversi dalla cache con timestamp confermato', () async {
    final voce = harness.firestore.doc('users/${harness.uid}/voci/b');
    await voce.set({
      'nome': 'BBVA',
      'tipo': 'semplice',
      'gruppo': 'liquidita',
      'ordine': 4,
      'saldoCentesimi': 10000,
    });
    expect(
      (await voce.get(
        const GetOptions(source: Source.cache),
      ))['saldoCentesimi'],
      10000,
    );
    await harness.impostaSaldoRemoto('b', 12000);
    expect(
      (await voce.get(
        const GetOptions(source: Source.cache),
      ))['saldoCentesimi'],
      10000,
    );
    final repo = FirestoreFotografieRepository(harness.uid, harness.firestore);
    final foto = await FotografieService(repo)
        .salvaNuovo(Mese(2026, 11), oggi: DateTime(2026, 11, 23));
    expect(foto.voci.single.saldoCentesimi, 12000);
    expect(foto.voci.single.id, 'b');
    expect(foto.salvataIl, isNotNull);
    expect(foto.revisione, 1);
    final riletta = await repo.leggi(Mese(2026, 11));
    expect(riletta!.voci.single.nome, 'BBVA');
    expect(riletta.voci.single.saldoCentesimi, 12000);
    expect(riletta.salvataIl, foto.salvataIl);
    expect((await repo.osserva().first).single.mese, Mese(2026, 11));
    await expectLater(
      repo.crea(foto),
      throwsA(isA<ConflittoFotografiaException>()),
    );
    expect((await repo.leggi(foto.mese))!.revisione, 1);
  });

  test(
    'FOT-010 scrittura ed eliminazione offline precedono la lettura server',
    () async {
      await harness.firestore
          .doc('users/${harness.uid}/fotografie/2026-11')
          .delete();
      final doc = harness.firestore.doc('users/${harness.uid}/voci/b');
      await doc.set({
        'nome': 'BBVA',
        'tipo': 'semplice',
        'gruppo': 'liquidita',
        'ordine': 0,
        'saldoCentesimi': 10000,
      });
      final eliminata = harness.firestore.doc('users/${harness.uid}/voci/c');
      await eliminata.set({
        'nome': 'Da eliminare',
        'tipo': 'semplice',
        'gruppo': 'liquidita',
        'ordine': 1,
        'saldoCentesimi': 5000,
      });
      await doc.get(const GetOptions(source: Source.server));
      await eliminata.get(const GetOptions(source: Source.server));
      final voci = FirestoreVociRepository(harness.uid, harness.firestore);
      final coordinator = OperazioniCoordinator();
      await harness.firestore.disableNetwork();
      final scrittura = coordinator.modifica(
        () => voci.salva(
          const Voce.semplice(
            id: 'b',
            nome: 'BBVA',
            gruppo: Gruppo.liquidita,
            saldoCentesimi: 20000,
          ),
        ),
      );
      final eliminazione = coordinator.modifica(() => voci.elimina('c'));
      final leaseFuture = coordinator.blocca();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(coordinator.bloccato, isTrue);
      await harness.firestore.enableNetwork();
      await Future.wait([scrittura, eliminazione]);
      final lease = await leaseFuture;
      final foto =
          await FotografieService(
            FirestoreFotografieRepository(harness.uid, harness.firestore),
          ).salvaNuovo(
            Mese(2026, 11),
            oggi: DateTime(2026, 11, 23),
            verificaOperazione: lease.verifica,
          );
      expect(foto.voci.map((voce) => voce.id), ['b']);
      expect(foto.voci.single.saldoCentesimi, 20000);
      expect(
        (await eliminata.get(const GetOptions(source: Source.server))).exists,
        isFalse,
      );
      lease.dispose();
      await eliminata.delete();
    },
  );

  test('FOT-012 offline non accoda la fotografia dopo il ripristino', () async {
    await harness.firestore
        .doc('users/${harness.uid}/fotografie/2026-11')
        .delete();
    final ref = harness.firestore.doc('users/${harness.uid}/voci/b');
    await ref.set({
      'nome': 'BBVA',
      'tipo': 'semplice',
      'gruppo': 'liquidita',
      'ordine': 0,
      'saldoCentesimi': 10000,
    });
    await ref.get(const GetOptions(source: Source.server));
    final db = harness.firestore;
    final repo = FirestoreFotografieRepository(harness.uid, db);
    await db.disableNetwork();
    await expectLater(
      FotografieService(repo)
          .salvaNuovo(Mese(2026, 11), oggi: DateTime(2026, 11, 23)),
      throwsA(anything),
    );
    await db.enableNetwork();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(await repo.leggi(Mese(2026, 11)), isNull);
    await ref.delete();
  });

  test(
    'FOT-014 documento sovradimensionato preserva la fotografia precedente',
    () async {
      final repo = FirestoreFotografieRepository(
        harness.uid,
        harness.firestore,
      );
      final mese = Mese(2026, 10);
      final precedente = await repo.crea(
        FotografiaMensile(
          mese: mese,
          voci: const [
            Voce.semplice(
              id: 'precedente',
              nome: 'Esistente',
              gruppo: Gruppo.liquidita,
            ),
          ],
        ),
      );
      final enorme = FotografiaMensile(
        mese: mese,
        voci: [
          Voce.semplice(
            id: 'grande',
            nome: List.filled(1100000, 'x').join(),
            gruppo: Gruppo.liquidita,
          ),
        ],
      );
      await expectLater(
        repo.sostituisci(enorme, precedente),
        throwsA(anything),
      );
      final riletta = await repo.leggi(mese);
      expect(riletta!.revisione, precedente.revisione);
      expect(riletta.voci.single.id, 'precedente');
      await harness.firestore
          .doc('users/${harness.uid}/fotografie/${mese.id}')
          .delete();
    },
  );

  test(
    'FOT-008 FOT-009 sostituzione integrale e revisione condizionata',
    () async {
      final repo = FirestoreFotografieRepository(
        harness.uid,
        harness.firestore,
      );
      final mese = Mese(2026, 10);
      final prima = await repo.crea(
        FotografiaMensile(
          mese: mese,
          voci: [
            Voce.conDettaglio(
              id: 'da-rimuovere',
              nome: 'Vecchia',
              gruppo: Gruppo.liquidita,
              righe: const [Riga(id: 'riga-vecchia', nome: 'Deposito')],
            ),
            const Voce.semplice(
              id: 'altra',
              nome: 'Altro',
              gruppo: Gruppo.investimenti,
              categoria: CategoriaInvestimento.crypto,
            ),
          ],
        ),
      );
      final nuova = FotografiaMensile(
        mese: mese,
        voci: const [
          Voce.semplice(id: 'rimasta', nome: 'Nuova', gruppo: Gruppo.liquidita),
        ],
      );
      final salvata = await repo.sostituisci(nuova, prima);
      final riletta = await repo.leggi(mese);
      expect(
        (await repo.osserva().first).where((foto) => foto.mese == mese),
        hasLength(1),
      );
      expect(riletta!.revisione, 2);
      expect(riletta.voci.map((voce) => voce.id), ['rimasta']);
      expect(riletta.voci.single.nome, 'Nuova');
      expect(salvata.voci.single.id, 'rimasta');
      await expectLater(
        repo.sostituisci(nuova, prima),
        throwsA(isA<ConflittoFotografiaException>()),
      );
      expect((await repo.leggi(mese))!.revisione, 2);
    },
  );

  test('CAT-013 CAT-014 schema 2 round-trip, schema 1 invariato in lettura e sostituito alla conferma', () async {
    final repo = FirestoreFotografieRepository(harness.uid, harness.firestore);
    final nuovo = Mese(2026, 8);
    final vecchio = Mese(2026, 7);
    final investimento = [
      const Voce.semplice(
        id: 'inv',
        nome: 'ETF',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.depositoTitoli,
        saldoCentesimi: 900,
      ),
    ];
    final creata = await repo.crea(
      FotografiaMensile(mese: nuovo, voci: investimento),
    );
    final raw = await harness.firestore
        .doc('users/${harness.uid}/fotografie/${nuovo.id}')
        .get(const GetOptions(source: Source.server));
    expect(raw['versioneSchema'], 2);
    expect(raw['voci'][0]['categoria'], 'depositoTitoli');
    final riletta = (await repo.leggi(nuovo))!;
    expect(riletta.versioneSchema, 2);
    expect(riletta.voci.single.categoria, CategoriaInvestimento.depositoTitoli);
    expect(creata.salvataIl, riletta.salvataIl);

    final ref = harness.firestore.doc(
      'users/${harness.uid}/fotografie/${vecchio.id}',
    );
    await ref.set({
      'versioneSchema': 1,
      'revisione': 3,
      'salvataIl': Timestamp.fromDate(DateTime.utc(2026, 7, 31)),
      'voci': [
        {
          'id': 'inv',
          'nome': 'ETF',
          'gruppo': 'investimenti',
          'tipo': 'semplice',
          'ordine': 0,
          'saldoCentesimi': 500,
        },
      ],
    });
    Future<Map<String, dynamic>> documento() async =>
        (await ref.get(const GetOptions(source: Source.server))).data()!;
    final prima = await documento();
    final v1 = (await repo.leggi(vecchio))!;
    expect(v1.versioneSchema, 1);
    expect(v1.voci.single.categoria, isNull);
    expect((await repo.osserva().first).map((f) => f.mese), contains(vecchio));
    expect(await documento(), prima);

    final sostituita = await repo.sostituisci(
      FotografiaMensile(mese: vecchio, voci: investimento),
      v1,
    );
    expect(sostituita.versioneSchema, 2);
    expect(sostituita.revisione, 4);
    expect(
      sostituita.voci.single.categoria,
      CategoriaInvestimento.depositoTitoli,
    );
    expect((await documento())['versioneSchema'], 2);
  });
}
