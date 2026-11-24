import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IMP-018 la cartella dati e node_modules sono escluse da git', () {
    for (final p in [
      'tool/import_storico/dati/fotografie.json',
      '../scripts/import-storico/node_modules/x',
    ]) {
      final r = Process.runSync('git', ['check-ignore', '-q', p]);
      expect(r.exitCode, 0, reason: '$p non è ignorato');
    }
  });

  test('IMP-018 la tabella dei nomi non contiene importi', () {
    final text = File('tool/import_storico/tabella_nomi.json')
        .readAsStringSync();
    final importo = RegExp(r'^-?\d[\d.,]*\s*€?$');
    void check(Object? v) {
      switch (v) {
        case num():
          fail('numero nella tabella: $v');
        case String():
          expect(importo.hasMatch(v.trim()), isFalse, reason: v);
        case Map():
          v.values.forEach(check);
        case List():
          v.forEach(check);
      }
    }

    final json = jsonDecode(text) as Map<String, dynamic>;
    check(json);
    expect((json['voci'] as Map).length, 24);
  });
}
