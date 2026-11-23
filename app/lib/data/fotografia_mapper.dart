import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/fotografia_mensile.dart';
import '../domain/mese.dart';
import '../domain/voce.dart';
import 'voce_mapper.dart';

Map<String, Object?> fotografiaToMap(FotografiaMensile fotografia) {
  final ordini = <Gruppo, int>{};
  return {
    'versioneSchema': 1,
    'revisione': fotografia.revisione,
    'salvataIl': FieldValue.serverTimestamp(),
    'voci': [
      for (final voce in fotografia.voci)
        {
          'id': voce.id,
          ...voceToMap(
            voce,
            ordini[voce.gruppo] = (ordini[voce.gruppo] ?? -1) + 1,
          ),
        },
    ],
  };
}

FotografiaMensile fotografiaFromMap(String id, Map<String, dynamic> data) {
  if (data['versioneSchema'] != 1) {
    throw const FormatException('Versione fotografia non supportata');
  }
  final voci =
      [
        for (final v in data['voci'] as List)
          Map<String, dynamic>.from(v as Map),
      ]..sort((a, b) {
        final gruppo = Gruppo.values
            .byName(a['gruppo'] as String)
            .index
            .compareTo(Gruppo.values.byName(b['gruppo'] as String).index);
        return gruppo != 0
            ? gruppo
            : (a['ordine'] as int).compareTo(b['ordine'] as int);
      });
  return FotografiaMensile(
    mese: Mese.fromId(id),
    voci: [for (final v in voci) voceFromMap(v['id'] as String, v)],
    revisione: data['revisione'] as int,
    salvataIl: (data['salvataIl'] as Timestamp?)?.toDate(),
  );
}
