import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/fotografie_providers.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:fl_chart/fl_chart.dart';
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

Future<void> pump(
  WidgetTester tester, {
  required bool authenticated,
  FakeFotografieRepository? repository,
}) async {
  final repo = repository ?? FakeFotografieRepository();
  addTearDown(repo.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(
          _Gateway(authenticated ? 'u' : null),
        ),
        vociRepositoryProvider.overrideWithValue(FakeVociRepository([])),
        fotografieRepositoryProvider.overrideWithValue(repo),
        oggiProvider.overrideWithValue(() => DateTime(2026, 11, 24)),
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

  FakeFotografieRepository conStorico() {
    final repo = FakeFotografieRepository();
    for (final (m, liq, inv) in [
      (Mese(2022, 1), 1000, 5000),
      (Mese(2026, 3), 2000, 6000),
      (Mese(2026, 11), 3000, 7000),
    ]) {
      repo.fotografie[m.id] = FotografiaMensile(
        mese: m,
        voci: [
          Voce.semplice(
            id: 'b',
            nome: 'BBVA',
            gruppo: Gruppo.liquidita,
            saldoCentesimi: liq * 100,
          ),
          Voce.semplice(
            id: 'e',
            nome: 'ETF',
            gruppo: Gruppo.investimenti,
            categoria: CategoriaInvestimento.pianiAccumulo,
            saldoCentesimi: inv * 100,
          ),
        ],
      );
    }
    return repo;
  }

  Future<void> apriAndamento(WidgetTester tester) async {
    await pump(tester, authenticated: true, repository: conStorico());
    await tester.tap(find.text('Andamento'));
    await tester.pumpAndSettle();
  }

  LineChartData dati(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart)).data;

  testWidgets('AND-007 cambio del periodo', (tester) async {
    await apriAndamento(tester);
    expect(find.text('Gennaio 2022 – Novembre 2026'), findsOneWidget);
    expect(dati(tester).lineBarsData.first.spots, hasLength(59));
    expect(find.text('€ 10.000,00'), findsOneWidget);

    await tester.tap(find.text('12 mesi'));
    await tester.pumpAndSettle();
    expect(find.text('Dicembre 2025 – Novembre 2026'), findsOneWidget);
    expect(dati(tester).lineBarsData.first.spots, hasLength(12));
  });

  testWidgets('AND-016 valore al tocco e legenda', (tester) async {
    await apriAndamento(tester);
    await tester.tap(find.text('12 mesi'));
    await tester.pumpAndSettle();
    expect(dati(tester).lineBarsData, hasLength(3));
    expect(dati(tester).lineBarsData.first.spots[2].isNull(), isTrue);

    final box = tester.getRect(find.byType(LineChart));
    await tester.tapAt(Offset(box.right - 12, box.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('Novembre 2026'), findsWidgets);
    expect(find.textContaining('€ 7.000,00'), findsWidgets);

    await tester.tap(find.text('Investimenti'));
    await tester.pumpAndSettle();
    expect(dati(tester).lineBarsData, hasLength(2));
  });
}
