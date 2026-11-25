import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/broker_providers.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/domain/associazioni_broker.dart';
import 'package:personal_finance/domain/broker.dart';
import 'package:personal_finance/domain/conferma_broker.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:personal_finance/main.dart';

import '../data/fake_broker_repository.dart';
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

class _Sospeso extends FakeBrokerRepository {
  final c = Completer<void>();
  @override
  Stream<RilevazioneBroker?> osservaAttiva() async* {
    await c.future;
  }
}

const _nomeLungo =
    'Opzione AAPL call strike 250 scadenza dicembre nome molto lungo';

final _rilevazione = RilevazioneBroker(
  lettaIl: DateTime(2026, 11, 25),
  conti: [
    ContoBroker(
      id: 'c1',
      broker: 'IBKR',
      nome: 'Conto principale con un nome davvero molto lungo da gestire',
      stato: StatoCollegamento.attivo,
      datiIl: DateTime(2026, 11, 24),
      posizioniDatiIl: DateTime(2026, 11, 25),
      liquidita: const [LiquiditaBroker(valuta: 'EUR', importo: '1234.50')],
      posizioni: const [
        PosizioneBroker(
          id: 'p1',
          simbolo: 'AAPL',
          descrizione: 'Apple Inc.',
          tipo: TipoPosizione.azione,
          valuta: 'USD',
          quantita: '10',
          prezzo: '200',
          valore: '2000',
        ),
        PosizioneBroker(
          id: 'p2',
          simbolo: 'VWCE',
          descrizione: 'Vanguard FTSE All-World',
          tipo: TipoPosizione.etf,
          valuta: 'EUR',
          quantita: '5',
          prezzo: '120',
          valore: '600',
        ),
        PosizioneBroker(
          id: 'p3',
          simbolo: null,
          descrizione: _nomeLungo,
          tipo: TipoPosizione.opzione,
          valuta: 'USD',
          quantita: '-2',
          prezzo: '3.5',
          valore: '-700',
          opzione: OpzioneBroker(
            sottostanteSimbolo: 'AAPL',
            tipo: TipoOpzione.call,
            strike: '250',
            scadenza: '2026-12-18',
            moltiplicatore: '100',
          ),
        ),
      ],
    ),
    ContoBroker(
      id: 'c2',
      broker: 'DEGIRO',
      nome: 'DEGIRO',
      stato: StatoCollegamento.sconosciuto,
      datiIl: null,
      liquidita: const [],
      posizioni: const [],
    ),
  ],
);

Future<void> apri(WidgetTester tester, FakeBrokerRepository repo) async {
  tester.view.physicalSize = const Size(360, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(_Gateway()),
        vociRepositoryProvider.overrideWithValue(
          FakeVociRepository(const [
            Voce.semplice(
              id: 'li',
              nome: 'Liquidità IBKR',
              gruppo: Gruppo.liquidita,
            ),
            Voce.semplice(
              id: 'iv',
              nome: 'Investimenti IBKR',
              gruppo: Gruppo.investimenti,
            ),
            Voce.semplice(
              id: 'b',
              nome: 'BBVA',
              gruppo: Gruppo.liquidita,
              saldoCentesimi: 10000,
            ),
          ]),
        ),
        brokerRepositoryProvider.overrideWithValue(repo),
      ],
      child: const PersonalFinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Broker'));
  await tester.pump();
}

void main() {
  anteprimaTests();
  testWidgets('BRO-013 consultazione a 360 pixel con opzione short', (
    tester,
  ) async {
    await apri(tester, FakeBrokerRepository(_rilevazione));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Rilevazione del 25/11/2026'), findsOneWidget);
    expect(find.textContaining('1234.50'), findsOneWidget);
    expect(find.textContaining('Apple Inc.'), findsOneWidget);
    expect(find.textContaining('Vanguard'), findsOneWidget);
    expect(find.textContaining(_nomeLungo), findsOneWidget);
    expect(find.textContaining('-2'), findsWidgets);
    expect(find.textContaining('Call'), findsOneWidget);
    expect(find.textContaining('18/12/2026'), findsOneWidget);
    expect(find.textContaining('Dati del 24/11/2026'), findsOneWidget);
  });

  testWidgets('BRO-014 stato di caricamento', (tester) async {
    await apri(tester, _Sospeso());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'BRO-014 nessuna rilevazione e BRO-002 integrazione disattivata',
    (tester) async {
      await apri(tester, FakeBrokerRepository());
      await tester.pumpAndSettle();
      expect(find.text('Nessuna rilevazione disponibile'), findsOneWidget);
      // Le operazioni manuali restano raggiungibili.
      await tester.tap(find.widgetWithText(TextButton, 'Situazione'));
      await tester.pumpAndSettle();
      expect(find.text('BBVA'), findsWidgets);
    },
  );

  testWidgets('BRO-014 errore di lettura', (tester) async {
    await apri(tester, FakeBrokerRepository()..errore = StateError('x'));
    await tester.pumpAndSettle();
    expect(find.text('Impossibile leggere i dati dei broker'), findsOneWidget);
  });

  testWidgets('BRO-023 collegamento non attivo e data sconosciuta', (
    tester,
  ) async {
    await apri(tester, FakeBrokerRepository(_rilevazione));
    await tester.pumpAndSettle();
    expect(find.text('Stato del collegamento sconosciuto'), findsOneWidget);
    expect(find.text('Dati del: sconosciuta'), findsOneWidget);
    expect(find.text('Posizioni del: sconosciuta'), findsOneWidget);
    expect(find.text('Posizioni del 25/11/2026'), findsOneWidget);
  });
  testWidgets('BRO-015 conto non associato senza proposte, poi associazione', (
    tester,
  ) async {
    final repo = FakeBrokerRepository(_rilevazione);
    await apri(tester, repo);
    await tester.pumpAndSettle();
    expect(
      find.text('Liquidità: non associata, nessuna proposta'),
      findsNWidgets(2),
    );
    await tester.tap(find.text('Associa Liquidità').first);
    await tester.pumpAndSettle();
    expect(find.text('Investimenti IBKR'), findsNothing);
    await tester.tap(find.text('Liquidità IBKR'));
    await tester.pumpAndSettle();
    expect(find.text('Liquidità → Liquidità IBKR'), findsOneWidget);
    expect(repo.associazioni['c1']!.revisione, 1);
    // Una voce già usata non è più offerta all'altro conto.
    await tester.tap(find.text('Associa Liquidità').last);
    await tester.pumpAndSettle();
    expect(find.text('Liquidità IBKR'), findsNothing);
  });
}

final _rilEuro = RilevazioneBroker(
  id: 'g1',
  lettaIl: DateTime(2026, 11, 25),
  conti: [
    ContoBroker(
      id: 'c1',
      broker: 'IBKR',
      nome: 'IBKR',
      stato: StatoCollegamento.attivo,
      datiIl: DateTime(2026, 11, 24),
      liquidita: const [LiquiditaBroker(valuta: 'EUR', importo: '1234.50')],
      posizioni: const [
        PosizioneBroker(
          id: 'p',
          simbolo: 'AAPL',
          descrizione: null,
          tipo: TipoPosizione.azione,
          valuta: 'USD',
          quantita: '10',
          prezzo: '200',
          valore: '2000',
          equivalenteLiquidita: false,
        ),
      ],
    ),
  ],
);

Future<FakeBrokerRepository> _apriAnteprima(WidgetTester tester) async {
  final repo = FakeBrokerRepository(_rilEuro)
    ..associazioni['c1'] = const AssociazioniConto(
      revisione: 2,
      liquidita: 'li',
      investimenti: 'iv',
    );
  await apri(tester, repo);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Anteprima aggiornamento'));
  await tester.pumpAndSettle();
  return repo;
}

void anteprimaTests() {
  testWidgets(
    'SIT-BRO-001 anteprima con confronto, nessun saldo cambia; annullare non scrive',
    (tester) async {
      final repo = await _apriAnteprima(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Attuale € 0,00'), findsWidgets);
      expect(find.text('Proposto € 1.234,50'), findsOneWidget);
      expect(find.text('Differenza +€ 1.234,50'), findsOneWidget);
      expect(find.text('Dati del 24/11/2026'), findsWidgets);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Anteprima ·'), findsNothing);
      expect(repo.associazioni['c1']!.revisione, 2);
      await tester.tap(find.widgetWithText(TextButton, 'Situazione'));
      await tester.pumpAndSettle();
      expect(find.text('BBVA'), findsWidgets);
      expect(find.textContaining('1.234,50'), findsNothing);
    },
  );

  testWidgets(
    'BRO-018 BRO-020 SIT-BRO-002 componente bloccata non selezionabile, valida sì',
    (tester) async {
      await _apriAnteprima(tester);
      expect(
        find.textContaining('Bloccata: Cambio USD mancante'),
        findsOneWidget,
      );
      final caselle = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(caselle[0].onChanged, isNotNull);
      expect(caselle[1].onChanged, isNull);
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pump();
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .last
            .value,
        isFalse,
      );
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .first
            .value,
        isTrue,
      );
    },
  );

  testWidgets('SIT-BRO-002 conferma solo le componenti selezionate', (
    tester,
  ) async {
    final repo = await _apriAnteprima(tester);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Conferma'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Conferma'));
    await tester.pumpAndSettle();
    final c = repo.conferme.single;
    expect(c.rilevazioneId, 'g1');
    expect(c.associazioni['c1']!.revisione, 2);
    expect(c.saldi.single.voce.id, 'li');
    expect(c.saldi.single.proposto, 123450);
    expect(find.textContaining('Anteprima ·'), findsNothing);
    expect(find.text('Saldi aggiornati'), findsOneWidget);
  });

  testWidgets('SIT-BRO-003 conflitto: avviso, nessun ricalcolo ne reinvio', (
    tester,
  ) async {
    final repo = await _apriAnteprima(tester)
      ..erroreConferma = const ConflittoConfermaException('x');
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Conferma'));
    await tester.pumpAndSettle();
    expect(find.textContaining('nuova anteprima'), findsOneWidget);
    expect(find.text('Proposto € 1.234,50'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Conferma'))
          .onPressed,
      isNull,
    );
    expect(repo.conferme, isEmpty);
  });

  testWidgets('SIT-BRO-005 offline: errore e riprova, nulla accodato', (
    tester,
  ) async {
    final repo = await _apriAnteprima(tester)
      ..erroreConferma = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Conferma'));
    await tester.pumpAndSettle();
    expect(find.textContaining('serve la connessione'), findsOneWidget);
    repo.erroreConferma = null;
    await tester.tap(find.widgetWithText(TextButton, 'Conferma'));
    await tester.pumpAndSettle();
    expect(repo.conferme, hasLength(1));
  });

  testWidgets('SIT-BRO-006 anteprima di un altro utente: messaggio dedicato', (
    tester,
  ) async {
    final repo = await _apriAnteprima(tester);
    repo.erroreConferma = StateError('Anteprima di un altro utente');
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Conferma'));
    await tester.pumpAndSettle();
    expect(find.textContaining('altro utente'), findsOneWidget);
    expect(find.textContaining('serve la connessione'), findsNothing);
  });

  testWidgets('SIT-BRO-004 errore imprevisto: nessun rimando alla connessione', (
    tester,
  ) async {
    final repo = await _apriAnteprima(tester);
    repo.erroreConferma = const FormatException('x');
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Conferma'));
    await tester.pumpAndSettle();
    expect(find.textContaining('imprevisto'), findsOneWidget);
    expect(find.textContaining('serve la connessione'), findsNothing);
  });
}
