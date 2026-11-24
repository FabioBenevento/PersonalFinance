@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/firestore_voci_repository.dart';
import 'package:personal_finance/domain/situazione.dart';
import 'package:personal_finance/domain/voce.dart';

import 'support/firebase_emulator_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseEmulatorHarness harness;
  setUpAll(() async => harness = await FirebaseEmulatorHarness.open());
  tearDownAll(() async => harness.close());

  test(
    'CAT-003 categoria persistita senza perdere saldo, ordine e righe',
    () async {
      final doc = harness.firestore.doc('users/${harness.uid}/voci/b');
      await doc.set({
        'nome': 'Prestiti',
        'gruppo': 'investimenti',
        'tipo': 'dettaglio',
        'ordine': 7,
        'categoria': 'p2pLanding',
        'righe': [
          {'id': 'r', 'nome': 'Piattaforma', 'saldoCentesimi': 1234},
        ],
      });
      final repo = FirestoreVociRepository(harness.uid, harness.firestore);
      final originale = (await repo.osserva().first).single;
      expect(originale.categoria, CategoriaInvestimento.p2pLanding);
      await repo.salva(
        Situazione([originale])
            .modificaCategoria('b', CategoriaInvestimento.crypto)
            .voci
            .single,
      );
      final remoto = (await doc.get(const GetOptions(source: Source.server)))
          .data()!;
      expect(remoto, {
        'nome': 'Prestiti',
        'gruppo': 'investimenti',
        'tipo': 'dettaglio',
        'ordine': 7,
        'categoria': 'crypto',
        'righe': [
          {'id': 'r', 'nome': 'Piattaforma', 'saldoCentesimi': 1234},
        ],
      });
      final riletta = (await FirestoreVociRepository(
        harness.uid,
        harness.firestore,
      ).osserva().first).single;
      expect(riletta.id, 'b');
      expect(riletta.categoria, CategoriaInvestimento.crypto);
      expect(riletta.saldoCentesimi, 1234);
      expect(riletta.righe!.single.id, 'r');
    },
  );

  test(
    'CAT-002 CAT-004 CAT-005 creazione e spostamento persistono la scelta',
    () async {
      final repo = FirestoreVociRepository(harness.uid, harness.firestore);
      final doc = harness.firestore.doc('users/${harness.uid}/voci/b');
      for (final voce in [
        const Voce.semplice(
          id: 'b',
          nome: 'Nuova',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.depositoTitoli,
        ),
        const Voce.conDettaglio(
          id: 'b',
          nome: 'Nuova',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.crypto,
        ),
      ]) {
        await repo.salva(const Situazione([]).aggiungiVoce(voce).voci.single);
        final creata = (await repo.osserva().first).single;
        expect(creata.categoria, voce.categoria);
        expect(creata.conDettaglio, voce.conDettaglio);
        expect(creata.saldoCentesimi, 0);
      }
      final conSaldo = const Situazione([
        Voce.conDettaglio(
          id: 'b',
          nome: 'Prestiti',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.p2pLanding,
          righe: [Riga(id: 'r', nome: 'Piattaforma', saldoCentesimi: 1234)],
        ),
      ]);
      await repo.salva(conSaldo.voci.single);
      await repo.salva(conSaldo.spostaVoce('b', Gruppo.liquidita).voci.single);
      final remoto = (await doc.get(const GetOptions(source: Source.server)))
          .data()!;
      expect(remoto.containsKey('categoria'), isFalse);
      expect(remoto['gruppo'], 'liquidita');
      expect(remoto['tipo'], 'dettaglio');
      expect(remoto['righe'], [
        {'id': 'r', 'nome': 'Piattaforma', 'saldoCentesimi': 1234},
      ]);
      final uscita = (await repo.osserva().first).single;
      expect(uscita.categoria, isNull);
      expect(uscita.saldoCentesimi, 1234);
      await repo.salva(
        Situazione([uscita])
            .spostaVoce(
              'b',
              Gruppo.investimenti,
              categoria: CategoriaInvestimento.crypto,
            )
            .voci
            .single,
      );
      final rientro = (await FirestoreVociRepository(
        harness.uid,
        harness.firestore,
      ).osserva().first).single;
      expect(rientro.categoria, CategoriaInvestimento.crypto);
      expect(rientro.gruppo, Gruppo.investimenti);
      expect(rientro.id, 'b');
      expect(rientro.saldoCentesimi, 1234);
      expect(rientro.righe!.single.id, 'r');
    },
  );

  test(
    'CAT-019 adattatore distingue categoria sconosciuta e documento precedente',
    () async {
      final doc = harness.firestore.doc('users/${harness.uid}/voci/b');
      await doc.set({
        'nome': 'Pensionline',
        'gruppo': 'investimenti',
        'tipo': 'semplice',
        'ordine': 0,
        'saldoCentesimi': 2000,
        'categoria': 'sconosciuta',
      });
      final repo = FirestoreVociRepository(harness.uid, harness.firestore);
      await expectLater(repo.osserva().first, throwsFormatException);
      await doc.update({'categoria': FieldValue.delete()});
      final precedente = (await repo.osserva().first).single;
      expect(precedente.categoria, isNull);
      expect(precedente.saldoCentesimi, 2000);
    },
  );
}
