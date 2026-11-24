import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/fotografia_mapper.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';

Map<String, dynamic> _doc(int? versione, {String? categoria}) => {
  'versioneSchema': versione,
  'revisione': 1,
  'voci': [
    {
      'id': 'i',
      'nome': 'ETF',
      'gruppo': 'investimenti',
      'categoria': ?categoria,
      'tipo': 'semplice',
      'ordine': 0,
      'saldoCentesimi': 100,
    },
  ],
};

void main() {
  test('CAT-013 nuova fotografia scritta nello schema 2 con categorie', () {
    final map = fotografiaToMap(
      FotografiaMensile(
        mese: Mese(2026, 11),
        voci: const [
          Voce.semplice(
            id: 'i',
            nome: 'ETF',
            gruppo: Gruppo.investimenti,
            categoria: CategoriaInvestimento.crypto,
            saldoCentesimi: 100,
          ),
        ],
      ),
    );
    expect(map['versioneSchema'], 2);
    expect((map['voci'] as List).single['categoria'], 'crypto');
    expect(map['salvataIl'], isA<FieldValue>());
  });

  test('CAT-013 lettura schema 2 conserva versione e categoria', () {
    final f = fotografiaFromMap('2026-11', _doc(2, categoria: 'crypto'));
    expect(f.versioneSchema, 2);
    expect(f.haCategorie, isTrue);
    expect(f.voci.single.categoria, CategoriaInvestimento.crypto);
  });

  test('CAT-014 lettura schema 1 senza categorie dedotte', () {
    final f = fotografiaFromMap('2026-11', _doc(1));
    expect(f.versioneSchema, 1);
    expect(f.haCategorie, isFalse);
    expect(f.voci.single.categoria, isNull);
  });

  test(
    'CAT-019 versione sconosciuta, schema 2 incompleto o categoria non valida',
    () {
      for (final v in [null, 0, 3]) {
        expect(
          () => fotografiaFromMap('2026-11', _doc(v)),
          throwsFormatException,
        );
      }
      expect(
        () => fotografiaFromMap('2026-11', _doc(2)),
        throwsFormatException,
      );
      expect(
        () => fotografiaFromMap('2026-11', _doc(2, categoria: 'altro')),
        throwsFormatException,
      );
    },
  );
}
