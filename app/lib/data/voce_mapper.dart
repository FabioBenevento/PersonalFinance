import '../domain/voce.dart';

/// Documento Firestore di [voce]; [ordine] è la posizione nel gruppo.
Map<String, Object?> voceToMap(Voce voce, int ordine) => {
  'nome': voce.nome,
  'gruppo': voce.gruppo.name,
  if (voce.categoria != null) 'categoria': voce.categoria!.name,
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

/// Voce dal documento [data] con id [id]; inverso di [voceToMap].
Voce voceFromMap(String id, Map<String, Object?> data) {
  final nome = data['nome'] as String;
  final gruppo = Gruppo.values.byName(data['gruppo'] as String);
  final rawCategoria = data['categoria'];
  CategoriaInvestimento? categoria;
  if (rawCategoria != null) {
    if (rawCategoria is! String || gruppo != Gruppo.investimenti) {
      throw const FormatException('Categoria degli investimenti non valida');
    }
    try {
      categoria = CategoriaInvestimento.values.byName(rawCategoria);
    } on ArgumentError {
      throw const FormatException('Categoria degli investimenti non valida');
    }
  }
  if (data['tipo'] == 'dettaglio') {
    return Voce.conDettaglio(
      id: id,
      nome: nome,
      gruppo: gruppo,
      categoria: categoria,
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
    categoria: categoria,
    saldoCentesimi: data['saldoCentesimi'] as int,
  );
}
