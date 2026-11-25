import 'dart:async';

import 'package:personal_finance/data/broker_repository.dart';
import 'package:personal_finance/domain/associazioni_broker.dart';
import 'package:personal_finance/domain/broker.dart';
import 'package:personal_finance/domain/conferma_broker.dart';
import 'package:personal_finance/domain/voce.dart';

class FakeBrokerRepository implements BrokerRepository {
  FakeBrokerRepository([this.attiva]);
  RilevazioneBroker? attiva;
  Object? errore;
  final associazioni = <String, AssociazioniConto>{};
  final _cambi = StreamController<void>.broadcast();

  @override
  Stream<RilevazioneBroker?> osservaAttiva() async* {
    if (errore != null) throw errore!;
    yield attiva;
  }

  @override
  Stream<Map<String, AssociazioniConto>> osservaAssociazioni() async* {
    yield Map.of(associazioni);
    await for (final _ in _cambi.stream) {
      yield Map.of(associazioni);
    }
  }

  @override
  Future<void> salvaAssociazioni(
    String contoId,
    AssociazioniConto nuove,
  ) async {
    if ((associazioni[contoId]?.revisione ?? 0) != nuove.revisione - 1) {
      throw const ValidazioneException('Associazioni modificate altrove');
    }
    associazioni[contoId] = nuove;
    _cambi.add(null);
  }

  /// Conferme ricevute; [erroreConferma] le fa fallire.
  final conferme = <ConfermaBroker>[];
  Object? erroreConferma;

  @override
  Future<bool> confermaSaldi(ConfermaBroker conferma) async {
    if (erroreConferma != null) throw erroreConferma!;
    conferme.add(conferma);
    return true;
  }
}
