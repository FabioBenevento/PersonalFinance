import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/operazioni_coordinator.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/domain/voce.dart';

import 'fake_voci_repository.dart';

void main() {
  const voce = Voce.semplice(
    id: 'v20',
    nome: 'Pensionline',
    gruppo: Gruppo.investimenti,
    saldoCentesimi: 50000,
  );

  (ProviderContainer, FakeVociRepository) crea() {
    final repo = FakeVociRepository(const [voce]);
    final container = ProviderContainer(
      overrides: [vociRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container, repo);
  }

  Future<Voce> corrente(FakeVociRepository repo) async =>
      (await repo.osserva().first).single;

  test('CAT-020 la fotografia attende la migrazione pendente', () async {
    final (container, repo) = crea();
    final attesa = Completer<void>();
    repo.primaDiClassificare = attesa.future;
    final migrazione = container.read(migrazioneCategorieProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    var pronta = false;
    final lease = container.read(operazioniCoordinatorProvider).blocca().then((
      l,
    ) {
      pronta = true;
      return l;
    });
    await Future<void>.delayed(Duration.zero);
    expect(pronta, isFalse);

    attesa.complete();
    await migrazione;
    (await lease).dispose();
    expect((await corrente(repo)).categoria, isNotNull);
  });

  test('CAT-020 con le modifiche bloccate la migrazione non parte: errore ripetibile', () async {
    final (container, repo) = crea();
    final lease = await container.read(operazioniCoordinatorProvider).blocca();

    await expectLater(
      container.read(migrazioneCategorieProvider.future),
      throwsA(isA<ModificheBloccateException>()),
    );
    expect((await corrente(repo)).categoria, isNull);

    lease.dispose();
    container.invalidate(migrazioneCategorieProvider);
    await container.read(migrazioneCategorieProvider.future);
    expect(
      (await corrente(repo)).categoria,
      CategoriaInvestimento.pianiAccumulo,
    );
  });
}
