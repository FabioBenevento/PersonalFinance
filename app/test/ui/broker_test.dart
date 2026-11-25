import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/broker_providers.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/domain/broker.dart';
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
      stato: StatoCollegamento.daRinnovare,
      datiIl: null,
      liquidita: const [],
      posizioni: const [],
    ),
  ],
);

Future<void> apri(WidgetTester tester, FakeBrokerRepository repo) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(_Gateway()),
        vociRepositoryProvider.overrideWithValue(
          FakeVociRepository(const [
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

  testWidgets('BRO-023 collegamento da rinnovare e data sconosciuta', (
    tester,
  ) async {
    await apri(tester, FakeBrokerRepository(_rilevazione));
    await tester.pumpAndSettle();
    expect(find.text('Collegamento da rinnovare'), findsOneWidget);
    expect(find.text('Dati del: sconosciuta'), findsOneWidget);
  });
}
