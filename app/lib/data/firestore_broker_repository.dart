import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/broker.dart';
import 'broker_mapper.dart';
import 'broker_repository.dart';

class FirestoreBrokerRepository implements BrokerRepository {
  FirestoreBrokerRepository(this.uid, [FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final String uid;
  final FirebaseFirestore _db;

  @override
  Stream<RilevazioneBroker?> osservaAttiva() => _db
      .doc('users/$uid/brokerStato/snaptrade')
      .snapshots()
      .asyncMap((stato) async {
        final id = stato.data()?['attivaId'];
        if (id == null) return null;
        final ref = _db.doc('users/$uid/brokerRilevazioni/$id');
        final testata = await ref.get();
        if (!testata.exists) {
          throw const FormatException('Rilevazione broker attiva mancante');
        }
        final conti = await ref.collection('conti').get();
        final posizioni = await ref.collection('posizioni').get();
        return rilevazioneDaDocumenti(
          testata.data()!,
          [for (final d in conti.docs) d.data()],
          [for (final d in posizioni.docs) d.data()],
        );
      });
}
