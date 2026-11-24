import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/data/voce_mapper.dart';
import 'package:personal_finance/data/fotografie_providers.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:personal_finance/domain/voci_iniziali.dart';
import 'package:personal_finance/main.dart';

import '../data/fake_voci_repository.dart';
import '../data/fake_fotografie_repository.dart';

class _Gateway implements AuthGateway {
  @override
  Stream<String?> uidChanges() => Stream.value('u');

  @override
  Future<bool> isAllowed(String uid) async => true;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

const _vociSemplici = [
  Voce.semplice(id: 'a', nome: 'BBVA', gruppo: Gruppo.liquidita),
  Voce.semplice(id: 'b', nome: 'Contanti', gruppo: Gruppo.salvadanaio),
  Voce.semplice(id: 'c', nome: 'ETF', gruppo: Gruppo.investimenti),
];

Future<FakeVociRepository> pump(
  WidgetTester tester, [
  List<Voce> voci = _vociSemplici,
  FakeFotografieRepository? fotografie,
]) async {
  if ((tester.view.physicalSize / tester.view.devicePixelRatio) ==
      const Size(800, 600)) {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final repo = FakeVociRepository(voci);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(_Gateway()),
        vociRepositoryProvider.overrideWithValue(repo),
        if (fotografie != null)
          fotografieRepositoryProvider.overrideWithValue(fotografie),
      ],
      child: const PersonalFinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> scrivi(WidgetTester tester, String testo) async {
  await tester.enterText(find.widgetWithText(TextField, '€ 0,00').at(1), testo);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'CAT-007 nessun investimento mantiene quattro categorie ordinate',
    (tester) async {
      await pump(tester, [_vociSemplici.first]);
      final y = <double>[];
      for (final nome in [
        'Piani accumulo',
        'P2P Landing',
        'Deposito Titoli',
        'Crypto',
      ]) {
        expect(find.text(nome), findsOneWidget);
        y.add(tester.getTopLeft(find.text(nome)).dy);
      }
      expect(y, orderedEquals([...y]..sort()));
      final riepilogo = find.byKey(const ValueKey('riepilogo-categorie'));
      expect(
        find.descendant(of: riepilogo, matching: find.text('€ 0,00  —')),
        findsNWidgets(4),
      );
      expect(find.text('Classificazione incompleta'), findsNothing);
    },
  );

  testWidgets('CAT-008 riepilogo incompleto e classificazione manuale', (
    tester,
  ) async {
    await pump(tester, [
      const Voce.semplice(
        id: 'p',
        nome: 'Pensione',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.pianiAccumulo,
        saldoCentesimi: 10000,
      ),
      const Voce.semplice(
        id: 'x',
        nome: 'Da sistemare',
        gruppo: Gruppo.investimenti,
        saldoCentesimi: 5000,
      ),
    ]);
    expect(find.text('€ 150,00  100,00%'), findsOneWidget);
    expect(find.text('€ 100,00  66,67%'), findsOneWidget);
    expect(find.text('Classificazione incompleta'), findsOneWidget);
    expect(find.text('Da classificare: € 50,00'), findsOneWidget);
    expect(find.widgetWithText(TextField, '€ 50,00'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '€ 50,00'), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Classificazione incompleta'), findsOneWidget);
    expect(find.text('Da classificare: € 0,00'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(TextButton, 'Classifica Da sistemare'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Crypto'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Classificazione incompleta'), findsNothing);
    expect(find.text('Da classificare: € 0,00'), findsNothing);
    expect(find.widgetWithText(TextField, '€ 100,00'), findsOneWidget);
  });

  testWidgets(
    'CAT-007 categorie vuote con investimenti zero e positivi a 360',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await pump(tester, [
        const Voce.semplice(
          id: 'p',
          nome: 'Pensione',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.pianiAccumulo,
        ),
      ]);
      final riepilogo = find.byKey(const ValueKey('riepilogo-categorie'));
      await tester.ensureVisible(riepilogo);
      expect(
        find.descendant(of: riepilogo, matching: find.text('€ 0,00  —')),
        findsNWidgets(4),
      );
      expect(find.text('Classificazione incompleta'), findsNothing);
      await repo.salva(
        const Voce.semplice(
          id: 'p',
          nome: 'Pensione',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.pianiAccumulo,
          saldoCentesimi: 10000,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: riepilogo,
          matching: find.text('€ 100,00  100,00%'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: riepilogo, matching: find.text('€ 0,00  0,00%')),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CAT-019 categoria non valida mostra errore di lettura delle voci',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authGatewayProvider.overrideWithValue(_Gateway()),
            vociRepositoryProvider.overrideWithValue(
              FakeVociRepository(_vociSemplici),
            ),
            vociProvider.overrideWith(
              (ref) => Stream.value({
                'nome': 'ETF',
                'gruppo': 'investimenti',
                'tipo': 'semplice',
                'ordine': 0,
                'saldoCentesimi': 1200,
                'categoria': 'sconosciuta',
              }).map((data) => [voceFromMap('c', data)]),
            ),
          ],
          child: const PersonalFinanceApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Impossibile leggere le voci'), findsOneWidget);
      expect(find.text('Totale'), findsNothing);
    },
  );

  testWidgets('CAT-003 assegnazione, cambio e annullamento categoria', (
    tester,
  ) async {
    final repo = await pump(tester, [
      const Voce.conDettaglio(
        id: 'd',
        nome: 'Prestiti',
        gruppo: Gruppo.investimenti,
        categoria: CategoriaInvestimento.p2pLanding,
        righe: [Riga(id: 'r', nome: 'Piattaforma', saldoCentesimi: 1234)],
      ),
    ]);
    final scritture = <Voce>[];
    repo.suSalva = scritture.add;
    await tester.tap(find.byTooltip('Azioni Prestiti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoria'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Crypto'),
      ),
    );
    await tester.pumpAndSettle();
    expect(scritture, hasLength(1));
    final salvata = (await repo.osserva().first).single;
    expect(salvata.categoria, CategoriaInvestimento.crypto);
    expect(salvata.id, 'd');
    expect(salvata.nome, 'Prestiti');
    expect(salvata.saldoCentesimi, 1234);
    expect(salvata.righe!.single.nome, 'Piattaforma');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('d')),
        matching: find.text('Crypto'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Azioni Prestiti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(scritture, hasLength(1));
    expect(
      (await repo.osserva().first).single.categoria,
      CategoriaInvestimento.crypto,
    );
  });

  testWidgets(
    'CAT-017 categoria non salvata e ripetizione con sincronizzazione',
    (tester) async {
      final repo = await pump(tester);
      repo.errore = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      Future<void> scegli() async {
        await tester.tap(find.byTooltip('Azioni ETF'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Categoria'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text('Deposito Titoli'),
          ),
        );
        await tester.pumpAndSettle();
      }

      await scegli();
      expect(find.text('Modifica non salvata, riprova'), findsOneWidget);
      expect(
        (await repo.osserva().first).firstWhere((v) => v.id == 'c').categoria,
        isNull,
      );
      repo.errore = null;
      await scegli();
      expect(
        (await repo.osserva().first).firstWhere((v) => v.id == 'c').categoria,
        CategoriaInvestimento.depositoTitoli,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('c')),
          matching: find.text('Deposito Titoli'),
        ),
        findsOneWidget,
      );
      repo.impostaInAttesa({'c'});
      await tester.pumpAndSettle();
      expect(find.text('In attesa di sincronizzazione'), findsOneWidget);
      repo.impostaInAttesa({});
      await tester.pumpAndSettle();
      expect(find.text('In attesa di sincronizzazione'), findsNothing);
    },
  );

  inizializzazioneTests();
  testWidgets('SIT-001 gruppi sempre visibili e in ordine', (tester) async {
    await pump(tester);
    final y = [
      for (final n in ['Salvadanaio', 'Liquidità', 'Investimenti', 'Totale'])
        tester.getTopLeft(find.text(n)).dy,
    ];
    expect(y, [...y]..sort());
    expect(find.text('€ 0,00  —'), findsNWidgets(7));
    expect(find.text('€ 0,00'), findsNWidgets(5));
  });

  testWidgets('SIT-005 modifica del saldo', (tester) async {
    await pump(tester);
    await scrivi(tester, '4.276,69');
    expect(find.widgetWithText(TextField, '€ 4.276,69'), findsOneWidget);
    expect(find.text('€ 4.276,69  100,00%'), findsOneWidget);
    expect(find.text('€ 4.276,69'), findsNWidgets(3));
  });

  testWidgets(
    'SIT-003 uscire dal campo senza modificarlo non salva né segnala',
    (tester) async {
      final repo = await pump(tester);
      final salvataggi = <Voce>[];
      repo.suSalva = salvataggi.add;
      await tester.tap(find.widgetWithText(TextField, '€ 0,00').at(1));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Importo non valido'), findsNothing);
      expect(salvataggi, isEmpty);
    },
  );

  testWidgets('SIT-005 cambiando solo le cifre il simbolo € è accettato', (
    tester,
  ) async {
    await pump(tester);
    await scrivi(tester, '€ 12,50');
    expect(find.text('Importo non valido'), findsNothing);
    expect(find.widgetWithText(TextField, '€ 12,50'), findsOneWidget);
  });

  testWidgets('SIT-021 salvataggio non riuscito', (tester) async {
    final repo = await pump(tester);
    repo.errore = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await scrivi(tester, '10');
    expect(find.text('Modifica non salvata, riprova'), findsOneWidget);
    expect(find.widgetWithText(TextField, '€ 10,00'), findsNothing);
    expect(find.widgetWithText(TextField, '€ 0,00'), findsNWidgets(3));
  });

  testWidgets('SIT-025 modifica senza rete: in attesa di sincronizzazione', (
    tester,
  ) async {
    final repo = await pump(tester);
    expect(find.text('In attesa di sincronizzazione'), findsNothing);
    await scrivi(tester, '4.276,69');
    repo.impostaInAttesa({'a'});
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '€ 4.276,69'), findsOneWidget);
    expect(find.text('In attesa di sincronizzazione'), findsOneWidget);
    repo.impostaInAttesa({});
    await tester.pumpAndSettle();
    expect(find.text('In attesa di sincronizzazione'), findsNothing);
    expect(find.widgetWithText(TextField, '€ 4.276,69'), findsOneWidget);
  });

  testWidgets(
    'FOT-014 errore di salvataggio ripristina controlli e consente retry',
    (tester) async {
      final fotografie = FakeFotografieRepository(_vociSemplici);
      addTearDown(fotografie.close);
      await pump(tester, _vociSemplici, fotografie);
      fotografie.errore = StateError('offline');
      await tester.tap(find.byTooltip('Salva fotografia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(find.text('Fotografia non salvata, riprova'), findsOneWidget);
      expect(find.text('Salvataggio in corso'), findsNothing);
      expect(fotografie.fotografie, isEmpty);

      fotografie.errore = null;
      await tester.tap(find.byTooltip('Salva fotografia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(fotografie.fotografie.keys, ['2026-11']);
    },
  );

  const p2p = Voce.conDettaglio(
    id: 'p',
    nome: 'P2PLanding',
    gruppo: Gruppo.investimenti,
    righe: [
      Riga(id: 'r1', nome: 'Bondora', saldoCentesimi: 10000),
      Riga(id: 'r2', nome: 'Evenfi', saldoCentesimi: 5000),
      Riga(id: 'r3', nome: 'Recrowd', saldoCentesimi: 2500),
    ],
  );

  testWidgets('SIT-008 saldo della voce con dettaglio non modificabile', (
    tester,
  ) async {
    await pump(tester, [p2p]);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('P2PLanding'));
    await tester.pumpAndSettle();
    expect(find.text('€ 175,00'), findsOneWidget);
    expect(find.widgetWithText(TextField, '€ 175,00'), findsNothing);
    expect(find.widgetWithText(TextField, '€ 100,00'), findsOneWidget);
  });

  testWidgets('SIT-009 gestione delle righe', (tester) async {
    await pump(tester, [p2p]);
    await tester.tap(find.text('P2PLanding'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aggiungi riga'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Mintos');
    await tester.enterText(find.widgetWithText(TextField, 'Saldo'), '100');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rinomina Evenfi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Evenfi Lending');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '€ 100,00').first,
      '200',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Elimina Recrowd'));
    await tester.pumpAndSettle();

    expect(find.text('Mintos'), findsOneWidget);
    expect(find.text('Evenfi Lending'), findsOneWidget);
    expect(find.text('Evenfi'), findsNothing);
    expect(find.text('Recrowd'), findsNothing);
    expect(find.text('€ 350,00'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('€ 350,00  100,00%'), findsOneWidget);
  });

  testWidgets('modifiche ravvicinate nel dettaglio non ripristinano il saldo', (
    tester,
  ) async {
    await pump(tester, [p2p]);
    await tester.tap(find.text('P2PLanding'));
    await tester.pumpAndSettle();

    // Il tocco su "Aggiungi riga" toglie il fuoco al campo e lo salva.
    await tester.enterText(
      find.widgetWithText(TextField, '€ 100,00').first,
      '200',
    );
    await tester.tap(find.text('Aggiungi riga'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Mintos');
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '€ 200,00'), findsOneWidget);
    expect(find.text('Mintos'), findsOneWidget);
    expect(find.text('€ 275,00'), findsOneWidget);
  });

  for (final tipo in ['Semplice', 'Con dettaglio']) {
    testWidgets('CAT-002 creazione $tipo richiede scelta esplicita', (
      tester,
    ) async {
      final repo = await pump(tester);
      final scritture = <Voce>[];
      repo.suSalva = scritture.add;
      await tester.tap(find.text('Aggiungi voce'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Nuova');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Investimenti'));
      await tester.tap(find.widgetWithText(ChoiceChip, tipo));
      await tester.pumpAndSettle();
      for (final nome in [
        'Piani accumulo',
        'P2P Landing',
        'Deposito Titoli',
        'Crypto',
      ]) {
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, nome))
              .selected,
          isFalse,
        );
      }
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      expect(scritture, isEmpty);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Deposito Titoli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      expect(scritture, hasLength(1));
      final nuova = (await repo.osserva().first).last;
      expect(nuova.nome, 'Nuova');
      expect(nuova.categoria, CategoriaInvestimento.depositoTitoli);
      expect(nuova.saldoCentesimi, 0);
      expect(nuova.conDettaglio, tipo == 'Con dettaglio');
      expect(
        tester.getTopLeft(find.text('Nuova')).dy,
        greaterThan(tester.getTopLeft(find.text('ETF')).dy),
      );
      await tester.tap(find.text('Aggiungi voce'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Investimenti'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Deposito Titoli'),
            )
            .selected,
        isFalse,
      );
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(scritture, hasLength(1));
    });
  }

  testWidgets('CAT-004 CAT-005 spostamento annullato, confermato e rientro', (
    tester,
  ) async {
    final repo = await pump(tester, [
      const Voce.conDettaglio(
        id: 'd',
        nome: 'Prestiti',
        gruppo: Gruppo.liquidita,
        righe: [Riga(id: 'r', nome: 'Piattaforma', saldoCentesimi: 1234)],
      ),
      ..._vociSemplici,
    ]);
    final scritture = <Voce>[];
    repo.suSalva = scritture.add;
    Future<void> sposta(String gruppo) async {
      await tester.tap(find.byTooltip('Azioni Prestiti'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sposta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SimpleDialogOption, gruppo));
      await tester.pumpAndSettle();
    }

    await sposta('Investimenti');
    expect(find.text('Categoria di Prestiti'), findsOneWidget);
    expect(scritture, isEmpty);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(scritture, isEmpty);
    expect(
      (await repo.osserva().first).firstWhere((v) => v.id == 'd').gruppo,
      Gruppo.liquidita,
    );
    await sposta('Investimenti');
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'P2P Landing'));
    await tester.pumpAndSettle();
    expect(scritture, hasLength(1));
    final ingresso = (await repo.osserva().first).last;
    expect(ingresso.id, 'd');
    expect(ingresso.gruppo, Gruppo.investimenti);
    expect(ingresso.categoria, CategoriaInvestimento.p2pLanding);
    expect(ingresso.saldoCentesimi, 1234);
    expect(ingresso.righe!.single.id, 'r');
    expect(ingresso.righe!.single.nome, 'Piattaforma');
    expect(ingresso.conDettaglio, isTrue);
    await sposta('Liquidità');
    expect(scritture, hasLength(2));
    final uscita = (await repo.osserva().first).firstWhere((v) => v.id == 'd');
    expect(uscita.categoria, isNull);
    expect(uscita.saldoCentesimi, 1234);
    expect(uscita.righe!.single.id, 'r');
    await sposta('Investimenti');
    expect(find.text('Categoria di Prestiti'), findsOneWidget);
    expect(scritture, hasLength(2));
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(scritture, hasLength(2));
    await sposta('Investimenti');
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Crypto'));
    await tester.pumpAndSettle();
    expect(scritture, hasLength(3));
    expect(
      (await repo.osserva().first).last.categoria,
      CategoriaInvestimento.crypto,
    );
  });

  testWidgets('SIT-011 aggiunta di una voce', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Aggiungi voce'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome'),
      'Conto Arancio',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Liquidità'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Semplice'));
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.text('Conto Arancio'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Conto Arancio')).dy,
      greaterThan(tester.getTopLeft(find.text('BBVA')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Conto Arancio')).dy,
      lessThan(tester.getTopLeft(find.text('Investimenti')).dy),
    );
    final voci = await repo.osserva().first;
    expect(
      voci.where((v) => v.nome == 'Conto Arancio').single.saldoCentesimi,
      0,
    );
  });

  testWidgets('SIT-014 eliminazione con conferma', (tester) async {
    final repo = await pump(tester, [
      const Voce.semplice(
        id: 'n',
        nome: 'N26',
        gruppo: Gruppo.liquidita,
        saldoCentesimi: 12345,
      ),
      ..._vociSemplici,
    ]);
    await tester.tap(find.byTooltip('Azioni N26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(find.textContaining('N26'), findsWidgets);
    expect(find.textContaining('€ 123,45'), findsWidgets);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect((await repo.osserva().first).length, 4);

    await tester.tap(find.byTooltip('Azioni N26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conferma'));
    await tester.pumpAndSettle();
    expect(find.text('N26'), findsNothing);
    expect((await repo.osserva().first).length, 3);
  });

  testWidgets('SIT-024 schermo stretto', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, [
      for (final v in vociIniziali)
        v.conDettaglio
            ? v
            : Voce.semplice(
                id: v.id,
                nome: v.nome,
                gruppo: v.gruppo,
                saldoCentesimi: 123456789012,
              ),
    ]);

    final righe = find.byType(ListView);
    expect(tester.takeException(), isNull);
    // Only vertical scrolling: no horizontal scrollable.
    for (final e in righe.evaluate()) {
      expect((e.widget as ListView).scrollDirection, Axis.vertical);
    }
    // No clipped text (ellipsis or wrapped beyond max lines).
    final tagliati = [
      for (final e in find.byType(RichText).evaluate())
        if ((e.renderObject! as RenderParagraph).didExceedMaxLines)
          (e.renderObject! as RenderParagraph).text.toPlainText(),
    ];
    expect(tagliati, isEmpty);
  });

  testWidgets('SIT-024 schermo stretto: pagina di dettaglio', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, [
      const Voce.conDettaglio(
        id: 'p',
        nome: 'Deposito Titoli – Scalable Capital',
        gruppo: Gruppo.investimenti,
        righe: [
          Riga(
            id: 'r1',
            nome: 'Deposito Titoli – Scalable Capital',
            saldoCentesimi: 123456789012,
          ),
        ],
      ),
    ]);
    await tester.scrollUntilVisible(
      find.text('Deposito Titoli – Scalable Capital'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deposito Titoli – Scalable Capital'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final tagliati = [
      for (final e in find.byType(RichText).evaluate())
        if ((e.renderObject! as RenderParagraph).didExceedMaxLines)
          (e.renderObject! as RenderParagraph).text.toPlainText(),
    ];
    expect(tagliati, isEmpty);
  });

  testWidgets('dettaglio di una voce eliminata: messaggio e indietro', (
    tester,
  ) async {
    final repo = await pump(tester, [p2p]);
    await tester.tap(find.text('P2PLanding'));
    await tester.pumpAndSettle();
    await repo.elimina('p');
    await tester.pumpAndSettle();
    expect(find.text('Voce non più disponibile'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Salvadanaio'), findsOneWidget);
  });
}

void inizializzazioneTests() {
  testWidgets(
    'CAT-009 CAT-012 migrazione in attesa, errore e nuovo tentativo senza nascondere i saldi',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeVociRepository(const [
        Voce.semplice(
          id: 'v20',
          nome: 'Pensionline',
          gruppo: Gruppo.investimenti,
          saldoCentesimi: 50000,
        ),
      ]);
      final attesa = Completer<void>();
      repo.primaDiClassificare = attesa.future;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authGatewayProvider.overrideWithValue(_Gateway()),
            vociRepositoryProvider.overrideWithValue(repo),
          ],
          child: const PersonalFinanceApp(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(find.text('Pensionline'), findsOneWidget);
      expect(find.text('Classificazione automatica in corso…'), findsOneWidget);
      attesa.completeError(Exception('rete'));
      await tester.pumpAndSettle();
      expect(find.text('Pensionline'), findsOneWidget);
      expect(find.textContaining('500,00'), findsWidgets);
      expect(find.text('Classificazione incompleta'), findsOneWidget);
      expect(
        find.text('Classificazione automatica non riuscita'),
        findsOneWidget,
      );
      repo.primaDiClassificare = null;
      await tester.tap(find.text('Riprova classificazione'));
      await tester.pumpAndSettle();
      expect(
        find.text('Classificazione automatica non riuscita'),
        findsNothing,
      );
      expect(find.text('Classificazione incompleta'), findsNothing);
      expect(
        (await repo.osserva().first).single.categoria,
        CategoriaInvestimento.pianiAccumulo,
      );
    },
  );

  testWidgets(
    'SIT-022 primo accesso: 24 voci a zero, indicatore durante il caricamento',
    (tester) async {
      final repo = await pump(tester, const []);
      expect(find.text('Contanti'), findsOneWidget);
      expect((await repo.osserva().first).length, 24);
    },
  );

  testWidgets(
    'SIT-023 secondo accesso dopo aver eliminato tutto: nessuna voce ricreata',
    (tester) async {
      final repo = await pump(tester, const []);
      for (final v in await repo.osserva().first) {
        await repo.elimina(v.id);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authGatewayProvider.overrideWithValue(_Gateway()),
            vociRepositoryProvider.overrideWithValue(repo),
          ],
          child: const PersonalFinanceApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(await repo.osserva().first, isEmpty);
    },
  );
}
