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
      tester.widget<LineChart>(find.byType(LineChart).first).data;

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

    final box = tester.getRect(find.byType(LineChart).first);
    await tester.tapAt(Offset(box.right - 12, box.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('Novembre 2026'), findsWidgets);
    expect(find.textContaining('€ 7.000,00'), findsWidgets);

    await tester.tap(find.widgetWithText(FilterChip, 'Investimenti'));
    await tester.pumpAndSettle();
    expect(dati(tester).lineBarsData, hasLength(2));
  });

  Future<void> alto(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder riga(String chiave, String testo) => find.descendant(
    of: find.byKey(ValueKey(chiave)),
    matching: find.text(testo),
  );

  List<double> valori(WidgetTester tester, String chiave) => tester
      .widget<PieChart>(
        find.descendant(
          of: find.byKey(ValueKey(chiave)),
          matching: find.byType(PieChart),
        ),
      )
      .data
      .sections
      .map((s) => s.value)
      .toList();

  testWidgets('AND-010 composizione dell\'ultima fotografia', (tester) async {
    await alto(tester);
    await apriAndamento(tester);
    expect(find.byType(LineChart), findsNWidgets(2));
    expect(valori(tester, 'torta-gruppi'), [0, 3000, 7000]);
    expect(riga('torta-gruppi', '€ 3.000,00  30,00%'), findsOneWidget);
    expect(riga('torta-gruppi', '€ 7.000,00  70,00%'), findsOneWidget);
    expect(valori(tester, 'torta-categorie'), [7000, 0, 0, 0]);
    expect(riga('torta-categorie', '€ 7.000,00  100,00%'), findsOneWidget);
  });

  testWidgets('AND-011 scelta di un altro mese', (tester) async {
    await alto(tester);
    await apriAndamento(tester);
    await tester.tap(find.byKey(const ValueKey('selettore-mese')));
    await tester.pumpAndSettle();
    expect(find.text('Febbraio 2023'), findsNothing);
    await tester.tap(find.text('Gennaio 2022').last);
    await tester.pumpAndSettle();
    expect(valori(tester, 'torta-gruppi'), [0, 1000, 5000]);
    expect(valori(tester, 'torta-categorie'), [5000, 0, 0, 0]);
    expect(riga('torta-categorie', '€ 5.000,00  100,00%'), findsOneWidget);
  });

  testWidgets('AND-012 categorie non disponibili', (tester) async {
    await alto(tester);
    final repo = FakeFotografieRepository();
    repo.fotografie[Mese(2026, 11).id] = FotografiaMensile(
      mese: Mese(2026, 11),
      versioneSchema: 1,
      voci: [
        Voce.semplice(
          id: 'b',
          nome: 'BBVA',
          gruppo: Gruppo.liquidita,
          saldoCentesimi: 300000,
        ),
        Voce.semplice(
          id: 'e',
          nome: 'ETF',
          gruppo: Gruppo.investimenti,
          saldoCentesimi: 700000,
        ),
      ],
    );
    await pump(tester, authenticated: true, repository: repo);
    await tester.tap(find.text('Andamento'));
    await tester.pumpAndSettle();
    expect(valori(tester, 'torta-gruppi'), [0, 3000, 7000]);
    expect(find.byKey(const ValueKey('torta-categorie')), findsNothing);
    expect(
      find.text('Riepilogo per categoria non disponibile'),
      findsOneWidget,
    );
  });

  testWidgets('AND-014 mese di confronto mancante', (tester) async {
    await alto(tester);
    final repo = FakeFotografieRepository();
    for (final (m, importo) in [
      (Mese(2026, 1), 100000),
      (Mese(2026, 9), 150000),
    ]) {
      repo.fotografie[m.id] = FotografiaMensile(
        mese: m,
        voci: [
          Voce.semplice(
            id: 'b',
            nome: 'BBVA',
            gruppo: Gruppo.liquidita,
            saldoCentesimi: importo,
          ),
        ],
      );
    }
    await pump(tester, authenticated: true, repository: repo);
    await tester.tap(find.text('Andamento'));
    await tester.pumpAndSettle();
    expect(riga('variazione-precedente', '—'), findsOneWidget);
    expect(find.text('nessuna fotografia di agosto 2026'), findsOneWidget);
    expect(riga('variazione-gennaio', '+€ 500,00 · +50,00%'), findsOneWidget);
    expect(find.text('nessuna fotografia di settembre 2025'), findsOneWidget);
  });

  testWidgets('AND-017 uso dal telefono', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await apriAndamento(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      ),
      findsNothing,
    );
    final x = <double>{};
    for (final k in [
      'variazione-precedente',
      'variazione-gennaio',
      'variazione-anno',
      'torta-gruppi',
      'torta-categorie',
    ]) {
      final f = find.byKey(ValueKey(k));
      await tester.scrollUntilVisible(f, 200);
      x.add(tester.getTopLeft(f).dx);
    }
    expect(tester.takeException(), isNull);
    expect(x.length, 1);
  });
}
