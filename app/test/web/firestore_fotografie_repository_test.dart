@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/firestore_fotografie_repository.dart';
import 'package:personal_finance/data/fotografie_service.dart';
import 'package:personal_finance/data/fotografie_repository.dart';
import 'package:personal_finance/domain/mese.dart';

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
}
