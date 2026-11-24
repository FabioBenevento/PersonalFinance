import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/fotografia_mapper.dart';

import '../../tool/import_storico/parser_foglio.dart';
import '../../tool/import_storico/prepara.dart';

final tabella = TabellaNomi.fromJson({
  'voci': {
    'Contanti': {'id': 'v0', 'nome': 'Contanti', 'gruppo': 'salvadanaio'},
    'Youbanking': {'id': 'v4', 'nome': 'Youbanking', 'gruppo': 'liquidita'},
    'Crypto': {
      'id': 'v22',
      'nome': 'Crypto',
      'gruppo': 'investimenti',
      'categoria': 'crypto',
    },
    'Hype': {'id': 's-hype', 'nome': 'Hype', 'gruppo': 'liquidita'},
  },
  'totali': ['Totale Liquidità', 'Totale Investimenti', 'Totale'],
  'ignorare': ['TFR'],
});

Map<String, dynamic> gen2022() => {
  'valido': null,
  'celle': [
    ['Contanti', '€ 910,00'],
    ['Youbanking', '€ 5.631,80'],
    ['Totale Liquidità', '€ 5.631,80'],
    ['Crypto', '€ 4.282,65'],
    ['Totale Investimenti', '€ 4.282,65'],
    ['Totale', '€ 10.824,45'],
  ],
};

Map<String, dynamic> ott2026() => {
  'valido': 'SI',
  'celle': [
    ['Contanti', '€ 10,00'],
    ['Crypto', '€ 100,00'],
    ['Totale Investimenti', '€ 50,00'],
  ],
};

Map<String, dynamic> portafoglio({String bwin = 'Bwin'}) => {
  'situazione': [
    ['Contanti', '€ 500,00'],
    ['MatchBetting', '€ 72,07'],
    ['Totale Liquidità', '€ 1,00'],
    ['TFR lordo', '€ 9,00'],
  ],
  'dettagli': {
    'MatchBetting': [
      ['Betfair', '€ 70,00'],
      [bwin, '€ 2,07'],
    ],
  },
};

void main() {
  test('IMP-016 saldi di oggi con ID, nomi attesi e righe', () {
    final t = TabellaNomi.fromJson({
      'voci': {
        'Contanti': {'id': 'v0', 'nome': 'Contanti', 'gruppo': 'salvadanaio'},
        'MatchBetting': {
          'id': 'v3',
          'nome': 'MatchBetting',
          'gruppo': 'salvadanaio',
        },
      },
      'totali': ['Totale Liquidità'],
      'ignorare': ['TFR'],
    });
    final s = preparaSaldiOggi(portafoglio(), t);
    expect(documentoSaldiOggi(s), {
      'v0': {'nome': 'Contanti', 'saldoCentesimi': 50000},
      'v3': {
        'nome': 'MatchBetting',
        'righe': {
          'v3-r0': {'nome': 'Betfair', 'saldoCentesimi': 7000},
          'v3-r2': {'nome': 'Bwin', 'saldoCentesimi': 207},
        },
      },
    });
    expect(s['v3']!.saldo, 7207);
    final r = scriviRevisione(Preparazione(), t, s);
    expect(r, contains('| Contanti | € 500,00 |'));
    expect(r, contains('| - Bwin | € 2,07 |'));
    expect(r, contains('Totale € 572,07'));
  });

  test('IMP-017 voce o riga non riconducibile ferma la preparazione', () {
    final t = TabellaNomi.fromJson({
      'voci': {
        'Contanti': {'id': 'v0', 'nome': 'Contanti', 'gruppo': 'salvadanaio'},
        'MatchBetting': {
          'id': 'v3',
          'nome': 'MatchBetting',
          'gruppo': 'salvadanaio',
        },
        'Hype': {'id': 's-hype', 'nome': 'Hype', 'gruppo': 'liquidita'},
      },
      'totali': ['Totale Liquidità'],
      'ignorare': ['TFR'],
    });
    expect(
      () => preparaSaldiOggi(portafoglio(bwin: 'Bwin2'), t),
      throwsA(
        isA<PreparazioneException>().having(
          (e) => e.message,
          'message',
          contains('Bwin2'),
        ),
      ),
    );
    final g = portafoglio();
    (g['situazione'] as List).add(['Hype', '€ 1,00']);
    expect(
      () => preparaSaldiOggi(g, t),
      throwsA(
        isA<PreparazioneException>().having(
          (e) => e.message,
          'message',
          contains('Hype'),
        ),
      ),
    );
  });

  test('IMP-001 IMP-003 mesi preparati, senza differenze (IMP-011)', () {
    final p = preparaMesi({
      '2022-01': gen2022(),
      '2026-09': gen2022(),
    }, tabella);
    expect(p.fotografie.keys, ['2022-01', '2026-09']);
    expect(p.differenze, isEmpty);
    final doc = documenti(p)['2022-01'] as Map<String, Object?>;
    expect(doc['versioneSchema'], 2);
    expect(doc.containsKey('salvataIl'), isFalse);
    // IMP-012 lato Dart: rilettura con schema 2
    final f = fotografiaFromMap('2022-01', jsonDecode(jsonEncode(doc)));
    expect(f.versioneSchema, 2);
    expect(f.situazione.totale, 1082445);
  });

  test('IMP-002 revisione con voci, somme e totale ricalcolato', () {
    final r = scriviRevisione(
      preparaMesi({'2022-01': gen2022()}, tabella),
      tabella,
    );
    expect(r, contains('| Contanti | Salvadanaio |  | € 910,00 |'));
    expect(r, contains('| Crypto | Investimenti | crypto | € 4.282,65 |'));
    expect(r, contains('Liquidità € 5.631,80'));
    expect(r, contains('Totale ricalcolato € 10.824,45'));
    expect(r, contains('| Hype | Hype | Liquidità |'));
  });

  test('IMP-004 mesi NO o vuoti saltati', () {
    final p = preparaMesi({
      '2026-08': {'valido': 'NO', 'celle': gen2022()['celle']},
      '2022-12': {
        'valido': null,
        'celle': [
          [],
          ['Totale', ''],
        ],
      },
    }, tabella);
    expect(p.fotografie, isEmpty);
    expect(p.saltati, {'2026-08': 'Valido = NO', '2022-12': 'foglio vuoto'});
    final r = scriviRevisione(p, tabella);
    expect(r, contains('- 2026-08: Valido = NO'));
    expect(r, contains('- 2022-12: foglio vuoto'));
  });

  test('IMP-010 differenza segnalata senza bloccare il mese', () {
    final p = preparaMesi({'2026-10': ott2026()}, tabella);
    expect(p.fotografie['2026-10']!.voci, hasLength(2));
    expect(p.differenze.single.etichetta, 'Totale Investimenti');
    final r = scriviRevisione(p, tabella);
    expect(
      r,
      contains(
        '- 2026-10 Totale Investimenti: foglio € 50,00, ricalcolato € 100,00, differenza -€ 50,00',
      ),
    );
  });

  test(
    'IMP-001 end-to-end su cartella temporanea, nessun file se bloccata',
    () {
      final base = Directory.systemTemp.createTempSync('prepara');
      addTearDown(() => base.deleteSync(recursive: true));
      Directory('${base.path}/dati/grezzi').createSync(recursive: true);
      File('${base.path}/tabella_nomi.json').writeAsStringSync(
        File('tool/import_storico/tabella_nomi.json').readAsStringSync(),
      );
      File('${base.path}/dati/grezzi/2022-01.json').writeAsStringSync(
        jsonEncode({
          'valido': null,
          'celle': [
            ['Contanti', '€ 910,00'],
            ['Totale', '€ 910,00'],
          ],
        }),
      );
      File('${base.path}/dati/grezzi/2026-11.json').writeAsStringSync(
        jsonEncode({
          'valido': 'SI',
          'celle': [
            ['Youbanking', '€ 1,00'],
          ],
        }),
      );
      preparaCartella(base);
      final out = jsonDecode(
        File('${base.path}/dati/fotografie.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(out.keys, ['2022-01', '2026-11']);
      expect(File('${base.path}/dati/revisione.md').existsSync(), isTrue);

      File('${base.path}/dati/fotografie.json').deleteSync();
      File('${base.path}/dati/grezzi/2022-02.json').writeAsStringSync(
        jsonEncode({
          'valido': null,
          'celle': [
            ['Hype2', '€ 1,00'],
          ],
        }),
      );
      expect(
        () => preparaCartella(base),
        throwsA(isA<PreparazioneException>()),
      );
      expect(File('${base.path}/dati/fotografie.json').existsSync(), isFalse);
    },
  );
}
