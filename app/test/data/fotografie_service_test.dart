import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/fotografie_service.dart';
import 'package:personal_finance/data/fotografie_repository.dart';
import 'package:personal_finance/data/operazioni_coordinator.dart';
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
  const nonClassificata = Voce.semplice(
    id: 'x',
    nome: 'Nuovo',
    gruppo: Gruppo.investimenti,
    saldoCentesimi: 0,
  );
  const classificata = Voce.semplice(
    id: 'x',
    nome: 'Nuovo',
    gruppo: Gruppo.investimenti,
    categoria: CategoriaInvestimento.crypto,
    saldoCentesimi: 0,
  );
  final oggi = DateTime(2026, 11, 23);

  test(
    'CAT-015 nuova fotografia bloccata sui dati server, anche a zero',
    () async {
      final repo = FakeFotografieRepository([nonClassificata]);
      final service = FotografieService(repo);
      await expectLater(
        service.salvaNuovo(Mese(2026, 11), oggi: oggi),
        throwsA(isA<ClassificazioneIncompletaException>()),
      );
      expect(repo.chiamate, isNot(contains('crea')));
      expect(repo.fotografie, isEmpty);
      repo.vociServer = [classificata];
      await service.salvaNuovo(Mese(2026, 11), oggi: oggi);
      expect(repo.chiamate.where((c) => c == 'crea'), hasLength(1));
      await repo.close();
    },
  );

  test(
    'CAT-015 il controllo usa le voci acquisite dopo la sincronizzazione',
    () async {
      final repo = FakeFotografieRepository([classificata]);
      final gate = Completer<void>();
      repo.sincronizzazione = gate.future;
      final risultato = FotografieService(repo)
          .salvaNuovo(Mese(2026, 11), oggi: oggi);
      final atteso = expectLater(
        risultato,
        throwsA(isA<ClassificazioneIncompletaException>()),
      );
      await Future<void>.delayed(Duration.zero);
      repo.vociServer = [nonClassificata];
      gate.complete();
      await atteso;
      expect(repo.fotografie, isEmpty);
      expect(repo.chiamate, isNot(contains('crea')));
      await repo.close();
    },
  );

  test(
    'CAT-016 sostituzione bloccata senza scritture e storico intatto',
    () async {
      final repo = FakeFotografieRepository([classificata]);
      final service = FotografieService(repo);
      final prima = await service.salvaNuovo(Mese(2026, 11), oggi: oggi);
      repo.vociServer = [nonClassificata];
      await expectLater(
        service.sostituisci(Mese(2026, 11), prima, oggi: oggi),
        throwsA(isA<ClassificazioneIncompletaException>()),
      );
      expect(repo.chiamate, isNot(contains('sostituisci')));
      final dopo = repo.fotografie['2026-11']!;
      expect(dopo.revisione, prima.revisione);
      expect(dopo.salvataIl, prima.salvataIl);
      expect(dopo.voci.single.categoria, CategoriaInvestimento.crypto);
      await repo.close();
    },
  );

  test(
    'CAT-020 acquisizione attende la categoria pendente e la rilegge',
    () async {
      final repo = FakeFotografieRepository([nonClassificata]);
      final coordinator = OperazioniCoordinator();
      final conferma = Completer<void>();
      final modifica = coordinator.modifica(() async {
        await conferma.future;
        repo.vociServer = [classificata];
      });
      final lease = coordinator.blocca();
      expect(
        () => coordinator.modifica(() async {}),
        throwsA(isA<ModificheBloccateException>()),
      );
      conferma.complete();
      await modifica;
      final l = await lease;
      final foto = await FotografieService(
        repo,
      ).salvaNuovo(Mese(2026, 11), oggi: oggi, verificaOperazione: l.verifica);
      expect(foto.voci.single.categoria, CategoriaInvestimento.crypto);
      l.dispose();
      await repo.close();
    },
  );

  test(
    'CAT-020 cambio account prima della scrittura impedisce il salvataggio',
    () async {
      final repo = FakeFotografieRepository([classificata]);
      final coordinator = OperazioniCoordinator();
      final l = await coordinator.blocca();
      repo.sincronizzazione = Future(() => coordinator.invalida());
      await expectLater(
        FotografieService(repo).salvaNuovo(
          Mese(2026, 11),
          oggi: oggi,
          verificaOperazione: l.verifica,
        ),
        throwsStateError,
      );
      expect(repo.fotografie, isEmpty);
      await repo.close();
    },
  );
}
