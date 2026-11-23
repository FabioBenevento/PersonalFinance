import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/domain/voce.dart';
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

Future<FakeVociRepository> pump(WidgetTester tester) async {
  final repo = FakeVociRepository([
    const Voce.semplice(id: 'a', nome: 'BBVA', gruppo: Gruppo.liquidita),
    const Voce.semplice(id: 'b', nome: 'Contanti', gruppo: Gruppo.salvadanaio),
    const Voce.semplice(id: 'c', nome: 'ETF', gruppo: Gruppo.investimenti),
  ]);
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
}
