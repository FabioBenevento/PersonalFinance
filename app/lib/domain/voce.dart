enum Gruppo { salvadanaio, liquidita, investimenti }

class Riga {
  const Riga({required this.id, required this.nome, this.saldoCentesimi = 0});

  final String id;
  final String nome;
  final int saldoCentesimi;
}

/// Voce semplice (saldo inserito) o con dettaglio (saldo = somma delle righe).
class Voce {
  const Voce.semplice({
    required this.id,
    required this.nome,
    required this.gruppo,
    int saldoCentesimi = 0,
  }) : _saldo = saldoCentesimi,
       righe = null;

  const Voce.conDettaglio({
    required this.id,
    required this.nome,
    required this.gruppo,
    this.righe = const [],
  }) : _saldo = 0;

  final String id;
  final String nome;
  final Gruppo gruppo;
  final int _saldo;

  /// Null per le voci semplici.
  final List<Riga>? righe;

  bool get conDettaglio => righe != null;

  int get saldoCentesimi =>
      righe?.fold<int>(0, (s, r) => s + r.saldoCentesimi) ?? _saldo;
}
