import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/associazioni_broker.dart';
import '../domain/broker.dart';
import '../domain/conferma_broker.dart';
import '../domain/voce.dart';
import 'broker_mapper.dart';
import 'broker_repository.dart';
import 'voce_mapper.dart';

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
          id: id as String,
        );
      });

  @override
  Stream<Map<String, AssociazioniConto>> osservaAssociazioni() => _db
      .collection('users/$uid/brokerAssociazioni')
      .snapshots()
      .map(
        (s) => {for (final d in s.docs) d.id: associazioniFromMap(d.data())},
      );

  @override
  Future<void> salvaAssociazioni(String contoId, AssociazioniConto nuove) {
    final ref = _db.doc('users/$uid/brokerAssociazioni/$contoId');
    return _db.runTransaction((t) async {
      final attuale = await t.get(ref);
      final revisione = attuale.exists
          ? associazioniFromMap(attuale.data()!).revisione
          : 0;
      if (revisione != nuove.revisione - 1) {
        throw const ValidazioneException('Associazioni modificate altrove');
      }
      t.set(ref, associazioniToMap(nuove));
    });
  }

  @override
  Future<void> confermaSaldi(ConfermaBroker c) async {
    if (c.saldi.isEmpty || c.saldi.any((s) => s.proposto < 0)) {
      throw const ValidazioneException('Selezione non valida');
    }
    final ricevuta = _db.doc('users/$uid/brokerApplicazioni/${c.operazioneId}');
    // Come per le fotografie: il conflitto esce dalla callback, perche sul web
    // l'errore della transazione arriva avvolto.
    String? conflitto;
    await _db.runTransaction<void>((t) async {
      conflitto = null;
      if ((await t.get(ricevuta)).exists) return; // gia applicata
      final stato = await t.get(_db.doc('users/$uid/brokerStato/snaptrade'));
      if (stato.data()?['attivaId'] != c.rilevazioneId) {
        conflitto = 'Rilevazione cambiata';
        return;
      }
      for (final e in c.associazioni.entries) {
        final doc = await t.get(
          _db.doc('users/$uid/brokerAssociazioni/${e.key}'),
        );
        final a = doc.exists
            ? associazioniFromMap(doc.data()!)
            : const AssociazioniConto();
        if (a.revisione != e.value.revisione ||
            a.liquidita != e.value.liquidita ||
            a.investimenti != e.value.investimenti) {
          conflitto = 'Associazioni cambiate';
          return;
        }
      }
      final refs = <DocumentReference<Map<String, dynamic>>>[];
      for (final s in c.saldi) {
        if (c.associazioni[s.contoId]?.destinazione(s.componente) !=
            s.voce.id) {
          conflitto = 'Associazioni cambiate';
          return;
        }
        final ref = _db.doc('users/$uid/voci/${s.voce.id}');
        final doc = await t.get(ref);
        final voce = doc.exists ? voceFromMap(doc.id, doc.data()!) : null;
        if (voce == null ||
            voce.conDettaglio ||
            voce.gruppo != s.voce.gruppo ||
            voce.categoria != s.voce.categoria ||
            voce.nome != s.voce.nome ||
            voce.saldoCentesimi != s.voce.saldoCentesimi) {
          conflitto = 'Voce cambiata o eliminata';
          return;
        }
        refs.add(ref);
      }
      final conti = <String, Map<String, Object>>{};
      for (final (i, s) in c.saldi.indexed) {
        t.update(refs[i], {'saldoCentesimi': s.proposto});
        (conti[s.contoId] ??= {})[s.componente.name] = {
          'voce': s.voce.id,
          'saldoCentesimi': s.proposto,
        };
      }
      t.set(ricevuta, {
        'rilevazione': c.rilevazioneId,
        'applicataAt': FieldValue.serverTimestamp(),
        'conti': conti,
      });
    });
    if (conflitto != null) throw ConflittoConfermaException(conflitto!);
  }
}
