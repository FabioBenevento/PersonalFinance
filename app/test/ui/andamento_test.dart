import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/fotografie_providers.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/main.dart';
import 'package:personal_finance/router.dart';

import '../data/fake_fotografie_repository.dart';
import '../data/fake_voci_repository.dart';

class _Gateway implements AuthGateway {
  _Gateway(this.uid);
  final String? uid;
  @override
  Stream<String?> uidChanges() => Stream.value(uid);
  @override
  Future<bool> isAllowed(String uid) async => true;
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}

Future<void> pump(WidgetTester tester, {required bool authenticated}) async {
  final repo = FakeFotografieRepository();
  addTearDown(repo.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(
          _Gateway(authenticated ? 'u' : null),
        ),
        vociRepositoryProvider.overrideWithValue(FakeVociRepository([])),
        fotografieRepositoryProvider.overrideWithValue(repo),
      ],
      child: const PersonalFinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AND-001 navigazione a tre schede', (tester) async {
    await pump(tester, authenticated: true);
    expect(find.text('Situazione'), findsWidgets);
    expect(find.text('Fotografie'), findsOneWidget);
    await tester.tap(find.text('Andamento'));
    await tester.pumpAndSettle();
    final router = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(routerProvider);
    expect(router.routeInformationProvider.value.uri.path, '/andamento');
    for (final n in ['Situazione', 'Fotografie', 'Andamento']) {
      expect(find.widgetWithText(TextButton, n), findsOneWidget);
    }
  });

  testWidgets('AND-002 accesso diretto senza sessione', (tester) async {
    await pump(tester, authenticated: false);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(routerProvider);
    router.go('/andamento');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/accesso');
    expect(find.text('Andamento'), findsNothing);
  });

  testWidgets('AND-003 storico vuoto', (tester) async {
    await pump(tester, authenticated: true);
    await tester.tap(find.text('Andamento'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Nessuna fotografia salvata: l'andamento comparirà dalla prima fotografia",
      ),
      findsOneWidget,
    );
  });
}
