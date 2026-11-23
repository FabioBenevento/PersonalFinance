import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:personal_finance/domain/voci_iniziali.dart';
import 'package:personal_finance/main.dart';

import '../data/fake_voci_repository.dart';

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
]) async {
  final repo = FakeVociRepository(voci);
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
  return repo;
}

Future<void> scrivi(WidgetTester tester, String testo) async {
  await tester.enterText(find.widgetWithText(TextField, '€ 0,00').at(1), testo);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SIT-001 gruppi sempre visibili e in ordine', (tester) async {
    await pump(tester);
    final y = [
      for (final n in ['Salvadanaio', 'Liquidità', 'Investimenti', 'Totale'])
        tester.getTopLeft(find.text(n)).dy,
    ];
    expect(y, [...y]..sort());
    expect(find.text('€ 0,00  —'), findsNWidgets(3));
    expect(find.text('€ 0,00'), findsNWidgets(4));
  });

  testWidgets('SIT-005 modifica del saldo', (tester) async {
    await pump(tester);
    await scrivi(tester, '4.276,69');
    expect(find.widgetWithText(TextField, '€ 4.276,69'), findsOneWidget);
    expect(find.text('€ 4.276,69  100,00%'), findsOneWidget);
    expect(find.text('€ 4.276,69'), findsNWidgets(2));
  });

  testWidgets('SIT-021 salvataggio non riuscito', (tester) async {
    final repo = await pump(tester);
    repo.errore = Exception('offline');
    await scrivi(tester, '10');
    expect(find.text('Modifica non salvata, riprova'), findsOneWidget);
    expect(find.widgetWithText(TextField, '€ 10,00'), findsNothing);
    expect(find.widgetWithText(TextField, '€ 0,00'), findsNWidgets(3));
  });

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
}
