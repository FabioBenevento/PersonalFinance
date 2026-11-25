import 'package:personal_finance/data/broker_repository.dart';
import 'package:personal_finance/domain/broker.dart';

class FakeBrokerRepository implements BrokerRepository {
  FakeBrokerRepository([this.attiva]);
  RilevazioneBroker? attiva;
  Object? errore;

  @override
  Stream<RilevazioneBroker?> osservaAttiva() async* {
    if (errore != null) throw errore!;
    yield attiva;
  }
}
