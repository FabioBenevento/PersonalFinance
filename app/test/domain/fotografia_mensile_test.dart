import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/voce.dart';

void main() {
  test('FOT-005 copia completa indipendente e calcoli della fotografia', () {
    final righe = [
      const Riga(id: 'r1', nome: 'BTC', saldoCentesimi: 2000),
      const Riga(id: 'r2', nome: 'ETH', saldoCentesimi: 3000),
    ];
    final voci = [
      const Voce.semplice(
        id: 'c',
        nome: 'Contanti',
        gruppo: Gruppo.salvadanaio,
        saldoCentesimi: 50000,
      ),
      const Voce.semplice(
        id: 'b',
        nome: 'BBVA',
        gruppo: Gruppo.liquidita,
        saldoCentesimi: 10000,
      ),
      Voce.conDettaglio(
        id: 'x',
        nome: 'Crypto',
        gruppo: Gruppo.investimenti,
        righe: righe,
      ),
    ];
    final foto = FotografiaMensile(mese: Mese(2026, 11), voci: voci);
    righe.clear();
    voci.clear();
    expect(foto.voci.map((v) => v.id), ['c', 'b', 'x']);
    expect(foto.voci.map((v) => v.nome), ['Contanti', 'BBVA', 'Crypto']);
    expect(foto.voci.last.gruppo, Gruppo.investimenti);
    expect(foto.voci.last.conDettaglio, isTrue);
    expect(foto.voci.last.righe!.map((r) => r.id), ['r1', 'r2']);
    expect(foto.voci.last.righe!.map((r) => r.nome), ['BTC', 'ETH']);
    expect(foto.voci.last.saldoCentesimi, 5000);
    expect(foto.situazione.totale, 65000);
    expect(foto.situazione.percentualeVoce(foto.voci.last), 10000);
    expect(foto.situazione.percentualeGruppo(Gruppo.investimenti), 769);
    expect(() => foto.voci.clear(), throwsUnsupportedError);
    expect(() => foto.voci.last.righe!.clear(), throwsUnsupportedError);
  });
  test('FOT-007 fotografia vuota o a zero conserva i tre gruppi', () {
    for (final voci in <List<Voce>>[
      [],
      [const Voce.semplice(id: 'b', nome: 'BBVA', gruppo: Gruppo.liquidita)],
    ]) {
      final foto = FotografiaMensile(mese: Mese(2026, 11), voci: voci);
      expect(foto.situazione.totale, 0);
      for (final gruppo in Gruppo.values) {
        expect(foto.situazione.totaleGruppo(gruppo), 0);
        expect(foto.situazione.percentualeGruppo(gruppo), isNull);
      }
      if (voci.isNotEmpty) {
        expect(foto.situazione.percentualeVoce(foto.voci.single), isNull);
      }
    }
  });
  test('FOT-003 mese invalido o futuro rifiutato', () {
    for (final month in [0, 13]) {
      expect(() => Mese(2026, month), throwsA(isA<ValidazioneException>()));
    }
    for (final year in [0, 10000]) {
      expect(() => Mese(year, 1), throwsA(isA<ValidazioneException>()));
    }
    expect(
      () => Mese(2026, 12).valida(DateTime(2026, 11, 23)),
      throwsA(isA<ValidazioneException>()),
    );
    Mese(2026, 11).valida(DateTime(2026, 11, 23));
    Mese(2021, 12).valida(DateTime(2026, 11, 23));
    expect(Mese(2026, 1).id, '2026-01');
    expect(Mese.fromId('2026-11'), Mese(2026, 11));
    expect(() => Mese.fromId('2026-1'), throwsA(isA<ValidazioneException>()));
  });
}
