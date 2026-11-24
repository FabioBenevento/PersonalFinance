/// Gruppo della Situazione Patrimoniale, nell'ordine di visualizzazione.
enum Gruppo { salvadanaio, liquidita, investimenti }

enum CategoriaInvestimento { pianiAccumulo, p2pLanding, depositoTitoli, crypto }

/// Operazione rifiutata; [message] dice il motivo.
class ValidazioneException implements Exception {
  const ValidazioneException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Riga di dettaglio di una voce con dettaglio, con il suo saldo in centesimi.
class Riga {
  const Riga({required this.id, required this.nome, this.saldoCentesimi = 0});

  final String id;
  final String nome;

  /// Saldo della riga in centesimi di euro.
  final int saldoCentesimi;

  Riga copyWith({String? nome, int? saldoCentesimi}) => Riga(
    id: id,
    nome: nome ?? this.nome,
    saldoCentesimi: saldoCentesimi ?? this.saldoCentesimi,
  );
}

/// Voce semplice (saldo inserito) o con dettaglio (saldo = somma delle righe).
class Voce {
  const Voce.semplice({
    required this.id,
    required this.nome,
    required this.gruppo,
    this.categoria,
    int saldoCentesimi = 0,
  }) : _saldoSemplice = saldoCentesimi,
       righe = null;

  const Voce.conDettaglio({
    required this.id,
    required this.nome,
    required this.gruppo,
    this.categoria,
    this.righe = const [],
  }) : _saldoSemplice = 0;

  final String id;
  final String nome;
  final Gruppo gruppo;
  final CategoriaInvestimento? categoria;

  /// Saldo inserito a mano: vale solo per le voci semplici (0 con dettaglio).
  final int _saldoSemplice;

  /// Null per le voci semplici.
  final List<Riga>? righe;

  /// Copia con i campi indicati sostituiti; il saldo semplice resta invariato.
  Voce copyWith({
    String? nome,
    Gruppo? gruppo,
    List<Riga>? righe,
    CategoriaInvestimento? categoria,
    bool rimuoviCategoria = false,
  }) {
    final cat = rimuoviCategoria ? null : categoria ?? this.categoria;
    return conDettaglio
        ? Voce.conDettaglio(
            id: id,
            nome: nome ?? this.nome,
            gruppo: gruppo ?? this.gruppo,
            categoria: cat,
            righe: righe ?? this.righe!,
          )
        : Voce.semplice(
            id: id,
            nome: nome ?? this.nome,
            gruppo: gruppo ?? this.gruppo,
            categoria: cat,
            saldoCentesimi: _saldoSemplice,
          );
  }

  /// Vero se il saldo è la somma delle righe.
  bool get conDettaglio => righe != null;

  /// Saldo in centesimi: quello inserito (semplice) o la somma delle righe.
  int get saldoCentesimi =>
      righe?.fold<int>(0, (s, r) => s + r.saldoCentesimi) ?? _saldoSemplice;
}
