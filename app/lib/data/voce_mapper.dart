import '../domain/voce.dart';

Map<String, Object?> voceToMap(Voce voce, int ordine) => {
  'nome': voce.nome,
  'gruppo': voce.gruppo.name,
  'tipo': voce.conDettaglio ? 'dettaglio' : 'semplice',
  'ordine': ordine,
  if (voce.conDettaglio)
    'righe': [
      for (final r in voce.righe!)
        {'id': r.id, 'nome': r.nome, 'saldoCentesimi': r.saldoCentesimi},
    ]
  else
    'saldoCentesimi': voce.saldoCentesimi,
};

Voce voceFromMap(String id, Map<String, Object?> data) {
  final nome = data['nome'] as String;
  final gruppo = Gruppo.values.byName(data['gruppo'] as String);
  if (data['tipo'] == 'dettaglio') {
    return Voce.conDettaglio(
      id: id,
      nome: nome,
      gruppo: gruppo,
      righe: [
        for (final r in data['righe'] as List)
          Riga(
            id: r['id'] as String,
            nome: r['nome'] as String,
            saldoCentesimi: r['saldoCentesimi'] as int,
          ),
      ],
    );
  }
  return Voce.semplice(
    id: id,
    nome: nome,
    gruppo: gruppo,
    saldoCentesimi: data['saldoCentesimi'] as int,
  );
}
