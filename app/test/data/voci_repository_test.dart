import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/inizializzazione_service.dart';
import 'package:personal_finance/domain/voce.dart';

import 'fake_voci_repository.dart';

const _iniziali = [
  Voce.semplice(id: 'v0', nome: 'Contanti', gruppo: Gruppo.salvadanaio),
  Voce.semplice(id: 'v1', nome: 'BBVA', gruppo: Gruppo.liquidita),
];

void main() {
  test(
    'CAT-009 CAT-010 CAT-011 migra identità iniziali una sola volta',
    () async {
      final repo = FakeVociRepository(const [
        Voce.semplice(
          id: 'v20',
          nome: 'Rinominata',
          gruppo: Gruppo.investimenti,
          saldoCentesimi: 345,
        ),
        Voce.semplice(
          id: 'v21',
          nome: 'Scelta',
          gruppo: Gruppo.investimenti,
          categoria: CategoriaInvestimento.crypto,
        ),
        Voce.semplice(id: 'v22', nome: 'Spostata', gruppo: Gruppo.liquidita),
        Voce.semplice(
          id: 'nuova',
          nome: 'Pensionline',
          gruppo: Gruppo.investimenti,
        ),
      ]);
      final service = InizializzazioneService(repo);
      await service.migraCategorie();
      await service.migraCategorie();
      final voci = await repo.osserva().first;
      expect(voci.length, 4);
      expect(
        voci.firstWhere((v) => v.id == 'v20').categoria,
        CategoriaInvestimento.pianiAccumulo,
      );
      expect(voci.firstWhere((v) => v.id == 'v20').saldoCentesimi, 345);
      expect(voci.firstWhere((v) => v.id == 'v20').nome, 'Rinominata');
      expect(
        voci.firstWhere((v) => v.id == 'v21').categoria,
        CategoriaInvestimento.crypto,
      );
      expect(voci.firstWhere((v) => v.id == 'v22').categoria, isNull);
      expect(voci.firstWhere((v) => v.id == 'nuova').categoria, isNull);
    },
  );

  test('SIT-022 primo accesso carica le voci iniziali', () async {
    final repo = FakeVociRepository();
    final service = InizializzazioneService(repo);
    expect(await service.inizializzaSeNecessario(_iniziali), isTrue);
    expect((await repo.osserva().first).map((v) => v.id), ['v0', 'v1']);
  });

  test(
    'SIT-023 nessun nuovo caricamento, anche dopo aver eliminato tutto',
    () async {
      final repo = FakeVociRepository();
      final service = InizializzazioneService(repo);
      await service.inizializzaSeNecessario(_iniziali);
      await repo.elimina('v0');
      await repo.elimina('v1');
      expect(await service.inizializzaSeNecessario(_iniziali), isFalse);
      expect(await repo.osserva().first, isEmpty);
    },
  );
}
