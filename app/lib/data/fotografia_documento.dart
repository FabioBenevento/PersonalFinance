import '../domain/fotografia_mensile.dart';
import '../domain/voce.dart';
import 'voce_mapper.dart';

/// Documento di schema 2 di [fotografia], senza `salvataIl`.
Map<String, Object?> fotografiaToDocumento(FotografiaMensile fotografia) {
  final ordini = <Gruppo, int>{};
  return {
    'versioneSchema': fotografia.versioneSchema,
    'revisione': fotografia.revisione,
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
