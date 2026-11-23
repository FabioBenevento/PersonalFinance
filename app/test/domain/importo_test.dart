import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/importo.dart';

void main() {
  test('SIT-002 importi validi', () {
    const casi = {
      '1.234,56': 123456,
      '1234,56': 123456,
      '1234.56': 123456,
      '1234': 123400,
      '0': 0,
      '0,5': 50,
    };
    casi.forEach((s, c) => expect(leggiImporto(s), c, reason: s));
  });

  test('SIT-003 importi non validi', () {
    for (final s in ['', 'abc', '-5', '12,345', '1,2,3', '1.23.4']) {
      expect(leggiImporto(s), isNull, reason: s);
    }
    expect(messaggioImportoNonValido, 'Importo non valido');
  });

  test('SIT-004 visualizzazione degli importi', () {
    expect(scriviImporto(5011000), '€ 50.110,00');
    expect(scriviImporto(40), '€ 0,40');
    expect(scriviImporto(123456780), '€ 1.234.567,80');
  });

  test('SIT-017 arrotondamento delle percentuali', () {
    expect(scriviPercentuale(3333), '33,33%');
    expect(scriviPercentuale(1250), '12,50%');
    expect(scriviPercentuale(2500), '25,00%');
  });

  test('SIT-018 base zero', () {
    expect(scriviPercentuale(null), '—');
  });
}
