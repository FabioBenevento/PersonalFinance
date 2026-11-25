import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/fotografie_providers.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voci_iniziali.dart';
import 'package:personal_finance/router.dart';
import 'package:personal_finance/main.dart';

import '../data/fake_fotografie_repository.dart';
import '../data/fake_voci_repository.dart';

class _Gateway implements AuthGateway {
  _Gateway([this.uid = 'u']);
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

const _voci = [
  Voce.semplice(
    id: 'b',
    nome: 'BBVA',
    gruppo: Gruppo.liquidita,
    saldoCentesimi: 10000,
  ),
];

Future<FakeVociRepository> pump(
  WidgetTester tester,
  FakeFotografieRepository repo, {
  DateTime? oggi,
  bool authenticated = true,
}) async {
  final voci = FakeVociRepository(_voci);
  addTearDown(repo.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(
          _Gateway(authenticated ? 'u' : null),
        ),
        vociRepositoryProvider.overrideWithValue(voci),
        fotografieRepositoryProvider.overrideWithValue(repo),
        oggiProvider.overrideWithValue(() => oggi ?? DateTime(2026, 11, 23)),
      ],
      child: const PersonalFinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
  return voci;
}

const _investiti = [
  Voce.semplice(
    id: 'e',
    nome: 'ETF',
    gruppo: Gruppo.investimenti,
    categoria: CategoriaInvestimento.depositoTitoli,
    saldoCentesimi: 70000,
  ),
  Voce.semplice(
    id: 'k',
    nome: 'Coin',
    gruppo: Gruppo.investimenti,
    categoria: CategoriaInvestimento.crypto,
    saldoCentesimi: 30000,
  ),
];

void main() {
  testWidgets('CAT-013 riepilogo storico indipendente dai dati attuali', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeFotografieRepository(_investiti);
    final mese = Mese(2026, 11);
    repo.fotografie[mese.id] = FotografiaMensile(mese: mese, voci: _investiti);
    final voci = await pump(tester, repo);
    await voci.salva(
      _investiti[0].copyWith(categoria: CategoriaInvestimento.p2pLanding),
    );
    await voci.elimina('k');
    await tester.tap(find.byTooltip('Fotografie mensili'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novembre 2026'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('riepilogo-categorie')),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(CategoriaInvestimento.depositoTitoli)),
        matching: find.textContaining('700,00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(CategoriaInvestimento.crypto)),
        matching: find.textContaining('300,00'),
      ),
      findsOneWidget,
    );
    expect(find.text('Classificazione incompleta'), findsNothing);
  });

  testWidgets('CAT-014 schema 1 mostra il riepilogo non disponibile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeFotografieRepository(_investiti);
    final mese = Mese(2026, 11);
    repo.fotografie[mese.id] = FotografiaMensile(
      mese: mese,
      voci: _investiti,
      versioneSchema: 1,
    );
    await pump(tester, repo);
    await tester.tap(find.byTooltip('Fotografie mensili'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novembre 2026'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Riepilogo per categoria non disponibile'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    expect(find.byKey(const ValueKey('riepilogo-categorie')), findsNothing);
    expect(find.text('ETF'), findsOneWidget);
    expect(repo.chiamate, isEmpty);
  });

  testWidgets('FOT-010 acquisizione aspetta la scrittura iniziata dal blur', (
    tester,
  ) async {
    final repo = FakeFotografieRepository(_voci);
    final vociFuture = Completer<void>();
    final voci = await pump(tester, repo);
    voci.primaDiSalva = vociFuture.future;
    voci.suSalva = (voce) => repo.vociServer = [voce];
    await tester.enterText(find.byType(TextField).first, '125,00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byTooltip('Salva fotografia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(repo.fotografie, isEmpty);
    vociFuture.complete();
    await tester.pumpAndSettle();
    expect(repo.fotografie['2026-11']!.voci.single.saldoCentesimi, 12500);
  });

  testWidgets('CAT-015 voce senza categoria a zero blocca e poi riesce', (
    tester,
  ) async {
    const incompleta = Voce.semplice(
      id: 'z',
      nome: 'Nuova',
      gruppo: Gruppo.investimenti,
      saldoCentesimi: 0,
    );
    final repo = FakeFotografieRepository([incompleta]);
    await pump(tester, repo);
    await tester.tap(find.byTooltip('Salva fotografia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(repo.fotografie, isEmpty);
    expect(
      find.textContaining('classifica prima tutte le voci'),
      findsOneWidget,
    );
    expect(find.text('Fotografia non salvata, riprova'), findsNothing);
    // I comandi sono di nuovo disponibili e un nuovo tentativo riesce.
    repo.vociServer = [
      incompleta.copyWith(categoria: CategoriaInvestimento.crypto),
    ];
    await tester.tap(find.byTooltip('Salva fotografia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(repo.fotografie.keys, ['2026-11']);
  });

  for (final schema in [1, 2]) {
    testWidgets(
      'CAT-016 sostituzione bloccata con fotografia schema $schema e comandi ripristinati',
      (tester) async {
        const incompleta = Voce.semplice(
          id: 'z',
          nome: 'Nuova',
          gruppo: Gruppo.investimenti,
          saldoCentesimi: 100,
        );
        final repo = FakeFotografieRepository([incompleta]);
        final mese = Mese(2026, 11);
        repo.fotografie[mese.id] = FotografiaMensile(
          mese: mese,
          voci: const [],
          versioneSchema: schema,
        );
        await pump(tester, repo);
        await tester.tap(find.byTooltip('Salva fotografia'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salva'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sostituisci'));
        await tester.pumpAndSettle();
        expect(repo.chiamate, isNot(contains('sostituisci')));
        expect(repo.fotografie[mese.id]!.voci, isEmpty);
        expect(
          find.textContaining('classifica prima tutte le voci'),
          findsOneWidget,
        );
        expect(find.text('Fotografia non salvata, riprova'), findsNothing);
        await tester.tap(find.byTooltip('Salva fotografia'));
        await tester.pumpAndSettle();
        expect(find.text('Salva'), findsOneWidget);
      },
    );
  }

  testWidgets('FOT-001 mese corrente e successo solo dopo conferma', (
    tester,
  ) async {
    final repo = FakeFotografieRepository(_voci);
    final attesa = Completer<void>();
    repo.sincronizzazione = attesa.future;
    await pump(tester, repo);
    await tester.tap(find.byTooltip('Salva fotografia'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '2026'), findsOneWidget);
    expect(find.text('Novembre'), findsOneWidget);
    await tester.tap(find.text('Salva'));
    await tester.pump();
    expect(repo.fotografie, isEmpty);
    expect(find.text('Fotografia salvata'), findsNothing);
    attesa.complete();
    await tester.pumpAndSettle();
    expect(repo.fotografie.keys, ['2026-11']);
    expect(find.text('Fotografia salvata'), findsOneWidget);
  });
  testWidgets('FOT-008 conferma sostituzione e annullamento non scrive', (
    tester,
  ) async {
    final repo = FakeFotografieRepository(_voci);
    final mese = Mese(2026, 11);
    repo.fotografie[mese.id] = FotografiaMensile(mese: mese, voci: const []);
    await pump(tester, repo);
    await tester.tap(find.byTooltip('Salva fotografia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sostituire la fotografia di Novembre 2026?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(repo.chiamate, isNot(contains('sostituisci')));
    expect(repo.fotografie[mese.id]!.voci, isEmpty);

    await tester.tap(find.byTooltip('Salva fotografia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sostituisci'));
    await tester.pumpAndSettle();
    expect(repo.chiamate, contains('sostituisci'));
    expect(repo.fotografie[mese.id]!.voci.single.id, 'b');
  });

  testWidgets('FOT-009 conflitto richiede una nuova conferma', (tester) async {
    final repo = FakeFotografieRepository(_voci);
    final mese = Mese(2026, 11);
    repo.fotografie[mese.id] = FotografiaMensile(mese: mese, voci: const []);
    var confliggi = true;
    repo.primaDiCreare = () {
      if (confliggi) {
        confliggi = false;
        repo.fotografie[mese.id] = FotografiaMensile(
          mese: mese,
          voci: const [],
          revisione: 2,
        );
      }
    };
    await pump(tester, repo);
    await tester.tap(find.byTooltip('Salva fotografia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sostituisci'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'La fotografia è cambiata. Confermi la sostituzione di Novembre 2026?',
      ),
      findsOneWidget,
    );
    expect(repo.fotografie[mese.id]!.revisione, 2);
    await tester.tap(find.text('Sostituisci'));
    await tester.pumpAndSettle();
    expect(repo.fotografie[mese.id]!.revisione, 3);
  });
  testWidgets(
    'FOT-002 FOT-004 mese passato, annullamento e nessun automatismo',
    (tester) async {
      final repo = FakeFotografieRepository(_voci);
      await pump(tester, repo);
      expect(repo.chiamate, isEmpty);
      await tester.tap(find.byTooltip('Salva fotografia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(repo.chiamate, isEmpty);
      await tester.tap(find.byTooltip('Salva fotografia'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '2021');
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(repo.fotografie.keys, ['2021-11']);
      expect(repo.fotografie['2021-11']!.situazione.totale, 10000);
    },
  );

  testWidgets(
    'FOT-016 FOT-017 FOT-006 archivio ordinato e dettaglio immutabile',
    (tester) async {
      final repo = FakeFotografieRepository(_voci);
      for (final mese in [Mese(2025, 12), Mese(2026, 1), Mese(2026, 11)]) {
        repo.fotografie[mese.id] = FotografiaMensile(
          mese: mese,
          voci: [
            Voce.conDettaglio(
              id: 'storica',
              nome: 'Conto storico',
              gruppo: Gruppo.liquidita,
              righe: [
                const Riga(
                  id: 'r',
                  nome: 'Deposito storico',
                  saldoCentesimi: 23000,
                ),
              ],
            ),
          ],
        );
      }
      final attuali = await pump(tester, repo);
      await tester.tap(find.byTooltip('Fotografie mensili'));
      await tester.pumpAndSettle();
      final mesi = find.byKey(const ValueKey('archivio-fotografie'));
      expect(
        tester
            .getTopLeft(
              find.descendant(of: mesi, matching: find.text('Novembre 2026')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.descendant(of: mesi, matching: find.text('Gennaio 2026')),
              )
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(
              find.descendant(of: mesi, matching: find.text('Gennaio 2026')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.descendant(of: mesi, matching: find.text('Dicembre 2025')),
              )
              .dy,
        ),
      );
      expect(find.text('Ottobre 2026'), findsNothing);
      await tester.tap(find.text('Novembre 2026').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conto storico'));
      await tester.pumpAndSettle();
      expect(find.text('Deposito storico'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect((await attuali.osserva().first).single.saldoCentesimi, 10000);
      expect(repo.chiamate, isEmpty);
    },
  );

  testWidgets('FOT-017 storico vuoto esplicito', (tester) async {
    final repo = FakeFotografieRepository(_voci);
    await pump(tester, repo);
    await tester.tap(find.byTooltip('Fotografie mensili'));
    await tester.pumpAndSettle();
    expect(find.text('Nessuna fotografia salvata'), findsOneWidget);
    expect(repo.fotografie, isEmpty);
  });
  testWidgets('FOT-015 errore di lettura archivio consente ripetizione', (
    tester,
  ) async {
    final repo = FakeFotografieRepository(_voci)
      ..errore = Exception('failed-precondition');
    await pump(tester, repo);
    await tester.tap(find.byTooltip('Fotografie mensili'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Impossibile leggere le fotografie, riprova'),
      findsOneWidget,
    );
    repo.errore = null;
    await tester.tap(find.text('Impossibile leggere le fotografie, riprova'));
    await tester.pumpAndSettle();
    expect(find.text('Nessuna fotografia salvata'), findsOneWidget);
  });
  testWidgets('FOT-020 destinazioni dirette protette senza sessione', (
    tester,
  ) async {
    final repo = FakeFotografieRepository(_voci);
    await pump(tester, repo, authenticated: false);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final router = container.read(routerProvider);
    for (final path in ['/fotografie', '/fotografie/2026-11']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/accesso');
      expect(find.text('Fotografie mensili'), findsNothing);
      expect(find.text('Accedi con Google'), findsOneWidget);
    }
    expect(repo.chiamate, isEmpty);
  });
  testWidgets('FOT-017 elenco e dettaglio sono viste successive su telefono', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeFotografieRepository(_voci);
    repo.fotografie['2026-11'] = FotografiaMensile(
      mese: Mese(2026, 11),
      voci: _voci,
    );
    await pump(tester, repo);
    await tester.tap(find.byTooltip('Fotografie mensili'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('archivio-fotografie')), findsOneWidget);
    expect(find.text('FOTOGRAFIA MENSILE'), findsNothing);
    await tester.tap(find.text('Novembre 2026'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('archivio-fotografie')), findsNothing);
    expect(find.text('FOTOGRAFIA MENSILE'), findsOneWidget);
    expect(find.text('BBVA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tutte le fotografie'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('archivio-fotografie')), findsOneWidget);
  });

  testWidgets('FOT-018 flussi fotografie usabili a 360 pixel con 24 voci', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeFotografieRepository(vociIniziali);
    final mese = Mese(2026, 11);
    repo.fotografie[mese.id] = FotografiaMensile(
      mese: mese,
      voci: vociIniziali,
    );
    await pump(tester, repo);

    Future<void> senzaOverflowOrizzontale() async {
      expect(tester.takeException(), isNull);
      for (final elemento in find.byType(ListView).evaluate()) {
        expect((elemento.widget as ListView).scrollDirection, Axis.vertical);
      }
      for (final elemento in find.byType(RenderBox).evaluate()) {
        final box = elemento.renderObject! as RenderBox;
        if (box.hasSize && box.attached) {
          final bounds = box.localToGlobal(Offset.zero) & box.size;
          expect(bounds.left, greaterThanOrEqualTo(-1));
          expect(bounds.right, lessThanOrEqualTo(361));
        }
      }
    }

    await tester.tap(find.byTooltip('Fotografie mensili'));
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);
    await senzaOverflowOrizzontale();

    await tester.tap(find.text('Novembre 2026'));
    await tester.pumpAndSettle();
    expect(find.text('FOTOGRAFIA MENSILE'), findsOneWidget);
    expect(repo.fotografie[mese.id]!.voci, hasLength(24));
    final voceDettagliata = vociIniziali.firstWhere((voce) => voce.id == 'v3');
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(voceDettagliata.nome));
    await tester.tap(find.text(voceDettagliata.nome));
    await tester.pumpAndSettle();
    expect(find.text(voceDettagliata.righe!.first.nome), findsOneWidget);
    await senzaOverflowOrizzontale();

    await tester.tap(find.text('Tutte le fotografie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Situazione'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Salva fotografia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sostituire la fotografia di Novembre 2026?'),
      findsOneWidget,
    );
    await senzaOverflowOrizzontale();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
