import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/data/operazioni_coordinator.dart';

void main() {
  test('FOT-010 acquisizione attende ogni modifica già avviata', () async {
    final coordinator = OperazioniCoordinator();
    final modifica = Completer<void>();
    final avviata = Completer<void>();
    final operazione = coordinator.modifica(() async {
      avviata.complete();
      await modifica.future;
    });
    await avviata.future;

    var acquisizionePronta = false;
    final leaseFuture = coordinator.blocca().then((lease) {
      acquisizionePronta = true;
      return lease;
    });
    await Future<void>.delayed(Duration.zero);
    expect(acquisizionePronta, isFalse);
    expect(
      () => coordinator.modifica(() async {}),
      throwsA(isA<ModificheBloccateException>()),
    );

    modifica.complete();
    await operazione;
    final lease = await leaseFuture;
    expect(lease.valida, isTrue);
    lease.dispose();
    expect(coordinator.bloccato, isFalse);
  });

  test('FOT-013 cambio account invalida lease e sblocca i comandi', () async {
    final coordinator = OperazioniCoordinator();
    final lease = await coordinator.blocca();
    coordinator.invalida();

    expect(lease.valida, isFalse);
    expect(() => lease.verifica(), throwsStateError);
    expect(coordinator.bloccato, isFalse);
    await coordinator.modifica(() async {});
  });

  test('FOT-010 errore di modifica interrompe acquisizione', () async {
    final coordinator = OperazioniCoordinator();
    final errore = StateError('write failed');
    final scrittura = Completer<void>();
    final operazione = coordinator.modifica(() => scrittura.future);
    final cattura = coordinator.blocca();
    scrittura.completeError(errore);
    await expectLater(operazione, throwsA(same(errore)));
    await expectLater(cattura, throwsA(same(errore)));
    expect(coordinator.bloccato, isFalse);
  });
}
