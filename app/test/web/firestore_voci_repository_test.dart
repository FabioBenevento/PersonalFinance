@TestOn('browser')
library;

import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/firestore_fotografie_repository.dart';
import 'package:personal_finance/data/firestore_voci_repository.dart';
import 'package:personal_finance/data/fotografie_service.dart';
import 'package:personal_finance/data/inizializzazione_service.dart';
import 'package:personal_finance/domain/mese.dart';
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

  test('CAT-009 CAT-010 CAT-011 CAT-012 migrazione per identita, ripetibile e concorrente', () async {
    final col = harness.firestore.collection('users/${harness.uid}/voci');
    Map<String, Object?> voce(
      String nome,
      String gruppo,
      int ordine, {
      int saldo = 100,
      String? categoria,
    }) => {
      'nome': nome,
      'gruppo': gruppo,
      'tipo': 'semplice',
      'ordine': ordine,
      'saldoCentesimi': saldo,
      'categoria': ?categoria,
    };
    // v14 rinominata, v15 con categoria scelta, v16 spostata, v17 eliminata
    // (mai creata), v20 voce omonima con altra identita.
    await col.doc('v14').set(voce('Rinominata', 'investimenti', 0));
    await col
        .doc('v15')
        .set(voce('Scelta', 'investimenti', 1, categoria: 'crypto'));
    await col.doc('v16').set(voce('Spostata', 'liquidita', 2));
    await col.doc('x1').set(voce('Pensionline', 'investimenti', 3));
    final repo = FirestoreVociRepository(harness.uid, harness.firestore);
    final foto = await FotografieService(
      FirestoreFotografieRepository(harness.uid, harness.firestore),
    ).salvaNuovo(Mese(2026, 11), oggi: DateTime(2026, 11, 23));
    final fotoRef = harness.firestore.doc(
      'users/${harness.uid}/fotografie/${foto.mese.id}',
    );
    const server = GetOptions(source: Source.server);
    final fotoPrima = (await fotoRef.get(server)).data();

    // Un altro dispositivo modifica un saldo mentre la migrazione e' in corso.
    await harness.impostaSaldoRemoto('v14', 777);
    final service = InizializzazioneService(repo);
    await service.migraCategorie();
    await service.migraCategorie();

    final v14 = (await col.doc('v14').get(server)).data()!;
    expect(
      v14,
      voce(
        'Rinominata',
        'investimenti',
        0,
        saldo: 777,
        categoria: 'p2pLanding',
      ),
    );
    expect(
      (await col.doc('v15').get(server)).data(),
      voce('Scelta', 'investimenti', 1, categoria: 'crypto'),
    );
    expect(
      (await col.doc('v16').get(server)).data(),
      voce('Spostata', 'liquidita', 2),
    );
    expect(
      (await col.doc('x1').get(server)).data(),
      voce('Pensionline', 'investimenti', 3),
    );
    expect((await col.doc('v17').get(server)).exists, isFalse);
    expect((await fotoRef.get(server)).data(), fotoPrima);
    for (final id in ['v14', 'v15', 'v16', 'x1']) {
      await col.doc(id).delete();
    }
  });

  // Deterministic injection without a new seam: the transaction reads the
  // documents first and only then looks up the categoria in the map, so the
  // first lookup runs after the read and before the commit. The server write
  // is started there, so it usually lands before the commit and forces a
  // re-evaluation; if the commit wins the order is the opposite. Both orders
  // must give the same result, hence the assertions on the final document only.
  Future<void> migraConScritturaConcorrente(
    FirestoreVociRepository repo,
    Map<String, CategoriaInvestimento> categorie,
    Future<void> Function() scrittura,
  ) async {
    var letture = 0;
    late Future<void> concorrente;
    await repo.classificaSeMancanti(
      _Interferente(categorie, () {
        if (letture++ == 0) concorrente = scrittura();
      }),
    );
    await concorrente;
  }

  test(
    'CAT-010 CAT-011 categoria scelta durante la migrazione vince',
    () async {
      final col = harness.firestore.collection('users/${harness.uid}/voci');
      await col.doc('c1').set({
        'nome': 'Da classificare',
        'gruppo': 'investimenti',
        'tipo': 'semplice',
        'ordine': 0,
        'saldoCentesimi': 100,
      });
      final repo = FirestoreVociRepository(harness.uid, harness.firestore);
      await migraConScritturaConcorrente(
        repo,
        {'c1': CategoriaInvestimento.p2pLanding},
        () => harness.scriviCampiRemoti('c1', {
          'categoria': {'stringValue': 'crypto'},
        }),
      );
      const server = GetOptions(source: Source.server);
      final remoto = (await col.doc('c1').get(server)).data()!;
      expect(remoto['categoria'], 'crypto');
      expect(remoto['saldoCentesimi'], 100);
      await col.doc('c1').delete();
    },
  );

  test(
    'CAT-010 CAT-012 saldo e righe modificati durante la migrazione restano',
    () async {
      final col = harness.firestore.collection('users/${harness.uid}/voci');
      await col.doc('c2').set({
        'nome': 'Con righe',
        'gruppo': 'investimenti',
        'tipo': 'dettaglio',
        'ordine': 0,
        'righe': [
          {'id': 'r', 'nome': 'Piattaforma', 'saldoCentesimi': 100},
        ],
      });
      final repo = FirestoreVociRepository(harness.uid, harness.firestore);
      await migraConScritturaConcorrente(
        repo,
        {'c2': CategoriaInvestimento.p2pLanding},
        () => harness.scriviCampiRemoti('c2', {
          'righe': {
            'arrayValue': {
              'values': [
                {
                  'mapValue': {
                    'fields': {
                      'id': {'stringValue': 'r'},
                      'nome': {'stringValue': 'Piattaforma'},
                      'saldoCentesimi': {'integerValue': '999'},
                    },
                  },
                },
              ],
            },
          },
        }),
      );
      const server = GetOptions(source: Source.server);
      expect((await col.doc('c2').get(server)).data(), {
        'nome': 'Con righe',
        'gruppo': 'investimenti',
        'tipo': 'dettaglio',
        'ordine': 0,
        'righe': [
          {'id': 'r', 'nome': 'Piattaforma', 'saldoCentesimi': 999},
        ],
        'categoria': 'p2pLanding',
      });
      await col.doc('c2').delete();
    },
  );
}

class _Interferente extends MapView<String, CategoriaInvestimento> {
  _Interferente(super.map, this._allaLettura);
  final void Function() _allaLettura;

  @override
  CategoriaInvestimento? operator [](Object? key) {
    _allaLettura();
    return super[key];
  }
}
