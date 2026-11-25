import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/fotografia_mensile.dart';
import '../domain/mese.dart';
import '../domain/voce.dart';
import 'fotografia_mapper.dart';
import 'fotografie_repository.dart';
import 'voce_mapper.dart';

class FirestoreFotografieRepository implements FotografieRepository {
  FirestoreFotografieRepository(this.uid, [FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _fotografie =>
      _db.collection('users/$uid/fotografie');

  @override
  Stream<List<FotografiaMensile>> osserva() => _fotografie.snapshots().map(
    (snapshot) => [
      for (final d in snapshot.docs) fotografiaFromMap(d.id, d.data()),
    ],
  );

  @override
  Future<FotografiaMensile?> leggi(Mese mese) async {
    final doc = await _fotografie
        .doc(mese.id)
        .get(const GetOptions(source: Source.server));
    return doc.exists ? fotografiaFromMap(doc.id, doc.data()!) : null;
  }

  @override
  Future<void> attendiSincronizzazione() => _db.waitForPendingWrites();

  @override
  Future<List<Voce>> acquisisciVoci() async {
    final snapshot = await _db
        .collection('users/$uid/voci')
        .get(const GetOptions(source: Source.server));
    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final gruppo = Gruppo.values
            .byName(a['gruppo'] as String)
            .index
            .compareTo(Gruppo.values.byName(b['gruppo'] as String).index);
        return gruppo != 0
            ? gruppo
            : (a['ordine'] as int).compareTo(b['ordine'] as int);
      });
    return [for (final d in docs) voceFromMap(d.id, d.data())];
  }

  @override
  Future<FotografiaMensile> crea(FotografiaMensile fotografia) async {
    final ref = _fotografie.doc(fotografia.mese.id);
    // Il plugin web non restituisce il risultato generico della transazione.
    // Il conflitto esce dalla callback, evitando anche la conversione in errore JS.
    FotografiaMensile? conflitto;
    await _db.runTransaction<void>((transaction) async {
      conflitto = null;
      final attuale = await transaction.get(ref);
      if (attuale.exists) {
        conflitto = fotografiaFromMap(attuale.id, attuale.data()!);
        return;
      }
      transaction.set(
        ref,
        fotografiaToMap(
          FotografiaMensile(mese: fotografia.mese, voci: fotografia.voci),
        ),
      );
    });
    if (conflitto != null) throw ConflittoFotografiaException(conflitto!);
    // La rilettura esplicita restituisce anche il timestamp risolto dal server.
    return (await leggi(fotografia.mese))!;
  }

  @override
  Future<FotografiaMensile> sostituisci(
    FotografiaMensile fotografia,
    FotografiaMensile attesa,
  ) async {
    final ref = _fotografie.doc(fotografia.mese.id);
    FotografiaMensile? conflitto;
    await _db.runTransaction<void>((transaction) async {
      conflitto = null;
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists ||
          snapshot.data()!['revisione'] != attesa.revisione) {
        conflitto = snapshot.exists
            ? fotografiaFromMap(snapshot.id, snapshot.data()!)
            : attesa;
        return;
      }
      transaction.set(
        ref,
        fotografiaToMap(
          FotografiaMensile(
            mese: fotografia.mese,
            voci: fotografia.voci,
            revisione: attesa.revisione + 1,
          ),
        ),
      );
    });
    if (conflitto != null) throw ConflittoFotografiaException(conflitto!);
    return (await leggi(fotografia.mese))!;
  }
}
