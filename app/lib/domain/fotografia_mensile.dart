import 'mese.dart';
import 'situazione.dart';
import 'voce.dart';

/// Schema 1: senza categorie (sola lettura); schema 2: categorie esplicite.
const schemaPrecedente = 1;
const schemaConCategorie = 2;

class FotografiaMensile {
  FotografiaMensile({
    required this.mese,
    required List<Voce> voci,
    this.revisione = 1,
    this.versioneSchema = schemaConCategorie,
    this.salvataIl,
  }) : voci = List.unmodifiable([
         for (final v in voci)
           if (v.conDettaglio)
             Voce.conDettaglio(
               id: v.id,
               nome: v.nome,
               gruppo: v.gruppo,
               categoria: v.categoria,
               righe: List.unmodifiable([
                 for (final r in v.righe!)
                   Riga(
                     id: r.id,
                     nome: r.nome,
                     saldoCentesimi: r.saldoCentesimi,
                   ),
               ]),
             )
           else
             Voce.semplice(
               id: v.id,
               nome: v.nome,
               gruppo: v.gruppo,
               categoria: v.categoria,
               saldoCentesimi: v.saldoCentesimi,
             ),
       ]);

  final Mese mese;
  final List<Voce> voci;
  final int revisione;
  final int versioneSchema;

  bool get haCategorie => versioneSchema >= schemaConCategorie;
  final DateTime? salvataIl;

  Situazione get situazione => Situazione(voci);
}
