import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/voce.dart';
import 'voce_mapper.dart';
import 'voci_repository.dart';

class FirestoreVociRepository implements VociRepository {
  FirestoreVociRepository(this.uid, [FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _utente => _db.doc('users/$uid');
  CollectionReference<Map<String, dynamic>> get _voci =>
      _utente.collection('voci');

  @override
  Stream<List<Voce>> osserva() => _voci.snapshots().map((s) {
    final docs = s.docs.toList()
      ..sort((a, b) {
        final g = Gruppo.values
            .byName(a['gruppo'] as String)
            .index
            .compareTo(Gruppo.values.byName(b['gruppo'] as String).index);
        return g != 0 ? g : (a['ordine'] as int).compareTo(b['ordine'] as int);
      });
    return [for (final d in docs) voceFromMap(d.id, d.data())];
  });

  @override
  Stream<Set<String>> osservaInAttesa() => _voci
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) => {
          for (final d in s.docs)
            if (d.metadata.hasPendingWrites) d.id,
        },
      );

  @override
  String nuovoId() => _voci.doc().id;

  @override
  Future<void> salva(Voce voce) async {
    // Solo cache: funziona senza rete, ed è completa perché osserva() ascolta
    // tutta la collezione.
    final gruppo = await _voci
        .where('gruppo', isEqualTo: voce.gruppo.name)
        .get(const GetOptions(source: Source.cache));
    final propria = gruppo.docs.where((d) => d.id == voce.id).firstOrNull;
    final ordine = propria != null
        ? propria['ordine'] as int
        : gruppo.docs.fold<int>(
                -1,
                (m, d) => (d['ordine'] as int) > m ? d['ordine'] as int : m,
              ) +
              1;
    await _voci.doc(voce.id).set(voceToMap(voce, ordine));
  }

  @override
  Future<void> elimina(String id) => _voci.doc(id).delete();

  @override
  Future<bool> inizializzato() async =>
      (await _utente.get()).data()?['inizializzato'] == true;

  @override
  Future<void> scriviIniziali(List<Voce> iniziali) async {
    final batch = _db.batch();
    final ordini = <Gruppo, int>{};
    for (final v in iniziali) {
      final ordine = ordini[v.gruppo] = (ordini[v.gruppo] ?? -1) + 1;
      batch.set(_voci.doc(v.id), voceToMap(v, ordine));
    }
    batch.set(_utente, {'inizializzato': true});
    await batch.commit();
  }

  @override
  Future<void> classificaSeMancanti(
    Map<String, CategoriaInvestimento> categorie,
  ) => _db.runTransaction((t) async {
    final docs = [for (final id in categorie.keys) await t.get(_voci.doc(id))];
    for (final d in docs) {
      final data = d.data();
      if (data == null ||
          data['gruppo'] != Gruppo.investimenti.name ||
          data['categoria'] != null) {
        continue;
      }
      t.update(d.reference, {'categoria': categorie[d.id]!.name});
    }
  });
}
