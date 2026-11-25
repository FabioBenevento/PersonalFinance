import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/broker_mapper.dart';
import 'package:personal_finance/data/broker_providers.dart';
import 'package:personal_finance/domain/associazioni_broker.dart';
import 'package:personal_finance/domain/broker.dart';

import 'fake_broker_repository.dart';

// Fixture condivisa con il comando Node.
Map<String, dynamic> _fixture() => jsonDecode(
  File('../scripts/sincronizza-broker/fixtures/rilevazione.json')
      .readAsStringSync(),
) as Map<String, dynamic>;

List<PosizioneBroker> _posizioni() =>
    rilevazioneFromJson(_fixture()).conti.single.posizioni;

({
  Map<String, dynamic> testata,
  List<Map<String, dynamic>> conti,
  List<Map<String, dynamic>> posizioni,
})
_documenti() {
  final f = _fixture();
  final conto = Map<String, dynamic>.from((f['conti'] as List).single as Map);
  final posizioni = [
    for (final p in conto.remove('posizioni') as List)
      {...Map<String, dynamic>.from(p as Map), 'contoId': conto['id']},
  ];
  return (
    testata: {
      'schemaVersion': f['schemaVersion'],
      'lettaIl': f['lettaIl'],
      'completa': true,
      'manifest': {'conti': 1, 'posizioni': posizioni.length},
    },
    conti: [conto],
    posizioni: posizioni,
  );
}

void main() {
  test('BRO-015 associazioni salvate con revisione e rilette', () {
    const a = AssociazioniConto(revisione: 2, liquidita: 'l');
    final m = associazioniToMap(a);
    expect(m, {'revisione': 2, 'liquidita': 'l'});
    final r = associazioniFromMap(m);
    expect(r.revisione, 2);
    expect(r.liquidita, 'l');
    expect(r.investimenti, isNull);
  });

  test('BRO-008 azioni ed ETF: decimali esatti, assenza distinta da zero', () {
    final p = _posizioni();
    final azione = p.firstWhere((x) => x.id == 'azione-demo');
    expect(azione.tipo, TipoPosizione.azione);
    expect(azione.quantita, '1.123456789012345678');
    expect(azione.valore, isNull);
    final etf = p.firstWhere((x) => x.id == 'etf-demo');
    expect(etf.quantita, '0.5');
    expect(etf.prezzo, '0');
    expect(etf.valore, isNull);
  });

  test('BRO-009 opzioni long e short con segni e valore non nozionale', () {
    final p = _posizioni();
    final call = p.firstWhere((x) => x.id == 'call-demo');
    expect(call.quantita, '2');
    expect(call.opzione!.tipo, TipoOpzione.call);
    expect(call.opzione!.sottostanteSimbolo, 'DEMO');
    expect(call.opzione!.strike, '125.50');
    expect(call.opzione!.scadenza, '2027-01-15');
    expect(call.opzione!.moltiplicatore, '100');
    final put = p.firstWhere((x) => x.id == 'put-demo');
    expect(put.quantita, '-3');
    expect(put.opzione!.tipo, TipoOpzione.put);
    expect(put.opzione!.moltiplicatore, '10');
    expect(put.valore, isNull);
  });

  test('BRO-010 tipo sconosciuto e campi mancanti non sono valorizzabili', () {
    final p = _posizioni();
    final ignoto = p.firstWhere((x) => x.id == 'ignoto-demo');
    expect(ignoto.tipo, TipoPosizione.sconosciuto);
    expect(ignoto.quantita, isNull);
    expect(ignoto.valorizzabile, isFalse);
    expect(p.firstWhere((x) => x.id == 'azione-demo').valorizzabile, isTrue);
  });

  test('BRO-023 data assente resta assente e collegamento da rinnovare non e proponibile', () {
    final f = _fixture();
    final conto = Map<String, dynamic>.from((f['conti'] as List).single as Map)
      ..['datiIl'] = null
      ..['statoCollegamento'] = 'da-rinnovare';
    final r = rilevazioneFromJson({
      ...f,
      'conti': [conto],
    });
    expect(r.conti.single.datiIl, isNull);
    expect(r.lettaIl, DateTime.utc(2026, 11, 25, 12));
    expect(r.conti.single.proponibile, isFalse);
    final attivo = rilevazioneFromJson(_fixture()).conti.single;
    expect(attivo.datiIl, DateTime.utc(2026, 11, 24, 18));
    expect(attivo.proponibile, isTrue);
  });

  test(
    'BRO-021 documenti completi ricomposti; staging incompleto rifiutato',
    () {
      final d = _documenti();
      final r = rilevazioneDaDocumenti(d.testata, d.conti, d.posizioni);
      expect(r.conti.single.posizioni, hasLength(5));
      expect(
        () => rilevazioneDaDocumenti(
          {...d.testata, 'completa': false},
          d.conti,
          d.posizioni,
        ),
        throwsFormatException,
      );
      expect(
        () => rilevazioneDaDocumenti(
          d.testata,
          d.conti,
          d.posizioni.take(3).toList(),
        ),
        throwsFormatException,
      );
    },
  );

  test('BRO-011 elenco valido vuoto distinto da errore', () {
    final d = _documenti();
    final vuota = rilevazioneDaDocumenti(
      {
        ...d.testata,
        'manifest': {'conti': 0, 'posizioni': 0},
      },
      [],
      [],
    );
    expect(vuota.conti, isEmpty);
    expect(
      () => rilevazioneDaDocumenti({...d.testata, 'manifest': null}, [], []),
      throwsFormatException,
    );
  });

  test(
    'BRO-001 due repository con gli stessi dati danno lo stesso risultato',
    () async {
      final dati = rilevazioneFromJson(_fixture());
      Future<List<String>> leggi(FakeBrokerRepository repo) async {
        final c = ProviderContainer(
          overrides: [brokerRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(c.dispose);
        final r = await _leggi(c);
        return [for (final x in r!.conti) '${x.id}:${x.posizioni.length}'];
      }

      expect(
        await leggi(FakeBrokerRepository(dati)),
        await leggi(_Altro(dati)),
      );
    },
  );

  test(
    'BRO-002 senza generazione attiva nessun dato e nessun errore',
    () async {
      final c = ProviderContainer(
        overrides: [
          brokerRepositoryProvider.overrideWithValue(FakeBrokerRepository()),
        ],
      );
      addTearDown(c.dispose);
      expect(await _leggi(c), isNull);
    },
  );

  test('BRO-011 errore del repository emesso senza nuovi tentativi', () async {
    final repo = FakeBrokerRepository()..errore = StateError('x');
    final c = ProviderContainer(
      overrides: [brokerRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    await expectLater(_leggi(c), throwsStateError);
  });
}

class _Altro extends FakeBrokerRepository {
  _Altro(super.r);
}

Future<RilevazioneBroker?> _leggi(ProviderContainer c) {
  c.listen(rilevazioneBrokerProvider, (_, _) {});
  return c.read(rilevazioneBrokerProvider.future);
}
