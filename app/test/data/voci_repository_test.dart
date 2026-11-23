import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/domain/voce.dart';

import 'fake_voci_repository.dart';

const _iniziali = [
  Voce.semplice(id: 'v0', nome: 'Contanti', gruppo: Gruppo.salvadanaio),
  Voce.semplice(id: 'v1', nome: 'BBVA', gruppo: Gruppo.liquidita),
];

void main() {
  test('SIT-022 primo accesso carica le voci iniziali', () async {
    final repo = FakeVociRepository();
    expect(await repo.inizializzaSeNecessario(_iniziali), isTrue);
    expect((await repo.osserva().first).map((v) => v.id), ['v0', 'v1']);
  });

  test(
    'SIT-023 nessun nuovo caricamento, anche dopo aver eliminato tutto',
    () async {
      final repo = FakeVociRepository();
      await repo.inizializzaSeNecessario(_iniziali);
      await repo.elimina('v0');
      await repo.elimina('v1');
      expect(await repo.inizializzaSeNecessario(_iniziali), isFalse);
      expect(await repo.osserva().first, isEmpty);
    },
  );
}
