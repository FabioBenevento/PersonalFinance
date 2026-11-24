import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/fotografia_mensile.dart';
import '../domain/mese.dart';
import '../domain/voce.dart';
import 'fotografia_documento.dart';
import 'voce_mapper.dart';

Map<String, Object?> fotografiaToMap(FotografiaMensile fotografia) => {
  ...fotografiaToDocumento(fotografia),
  'salvataIl': FieldValue.serverTimestamp(),
};

FotografiaMensile fotografiaFromMap(String id, Map<String, dynamic> data) {
  final versione = data['versioneSchema'];
  if (versione != schemaPrecedente && versione != schemaConCategorie) {
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
  final fotografia = FotografiaMensile(
    mese: Mese.fromId(id),
    voci: [for (final v in voci) voceFromMap(v['id'] as String, v)],
    revisione: data['revisione'] as int,
    versioneSchema: versione as int,
    salvataIl: (data['salvataIl'] as Timestamp?)?.toDate(),
  );
  if (fotografia.haCategorie &&
      !fotografia.situazione.classificazioneCompleta) {
    throw const FormatException('Fotografia con investimenti non classificati');
  }
  return fotografia;
}
