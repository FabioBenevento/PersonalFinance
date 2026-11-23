import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/fotografie_service.dart';
import 'package:personal_finance/data/fotografie_repository.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';

import 'fake_fotografie_repository.dart';

void main() {
  test(
    'FOT-011 acquisisce i saldi server solo dopo la sincronizzazione',
    () async {
      final repo = FakeFotografieRepository([
        const Voce.semplice(
          id: 'b',
          nome: 'BBVA',
          gruppo: Gruppo.liquidita,
          saldoCentesimi: 12000,
        ),
      ]);
      final gate = Completer<void>();
      repo.sincronizzazione = gate.future;
      final service = FotografieService(repo);
      final result = service.salvaNuovo(
        Mese(2026, 11),
        oggi: DateTime(2026, 11, 23),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.chiamate, ['leggi', 'sincronizza']);
      expect(await repo.osserva().first, isEmpty);
      gate.complete();
      final foto = await result;
      expect(repo.chiamate, ['leggi', 'sincronizza', 'acquisisci', 'crea']);
      expect(foto.voci.single.saldoCentesimi, 12000);
      expect((await repo.osserva().first).single.mese, Mese(2026, 11));
      await repo.close();
    },
  );
  test('FOT-003 servizio rifiuta futuro senza toccare repository', () async {
    final repo = FakeFotografieRepository();
    await expectLater(
      FotografieService(repo)
          .salvaNuovo(Mese(2026, 12), oggi: DateTime(2026, 11, 23)),
      throwsA(isA<ValidazioneException>()),
    );
    expect(repo.chiamate, isEmpty);
    await repo.close();
  });
  test(
    'FOT-011 creazione richiede un mese assente e conserva il precedente',
    () async {
      final repo = FakeFotografieRepository();
      final service = FotografieService(repo);
      final mese = Mese(2026, 11);
      await service.salvaNuovo(mese, oggi: DateTime(2026, 11, 23));
      await expectLater(
        service.salvaNuovo(mese, oggi: DateTime(2026, 11, 23)),
        throwsA(isA<ConflittoFotografiaException>()),
      );
      expect((await repo.osserva().first).length, 1);
      await repo.close();
    },
  );
}
