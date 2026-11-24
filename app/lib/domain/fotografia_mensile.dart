import 'mese.dart';
import 'situazione.dart';
import 'voce.dart';

class FotografiaMensile {
  FotografiaMensile({
    required this.mese,
    required List<Voce> voci,
    this.revisione = 1,
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
  final DateTime? salvataIl;

  Situazione get situazione => Situazione(voci);
}
