import 'importo.dart';
import 'voce.dart';

class Situazione {
  const Situazione(this.voci);

  final List<Voce> voci;

  int totaleGruppo(Gruppo g) => [
    for (final v in voci)
      if (v.gruppo == g) v.saldoCentesimi,
  ].fold(0, (a, b) => a + b);

  int get totale => Gruppo.values.fold(0, (s, g) => s + totaleGruppo(g));

  String percentualeVoce(Voce v) =>
      scriviPercentuale(v.saldoCentesimi, totaleGruppo(v.gruppo));

  String percentualeGruppo(Gruppo g) =>
      scriviPercentuale(totaleGruppo(g), totale);

  /// Aggiunge una voce in fondo al suo gruppo (l'ordine nella lista è l'ordine
  /// di visualizzazione).
  Situazione aggiungiVoce(Voce v) {
    final nome = _nomeValido(v.nome, voci.map((x) => x.nome), 'voce');
    return Situazione(_inFondoAlGruppo(voci, v.copyWith(nome: nome)));
  }

  Situazione rinominaVoce(String id, String nome) {
    final n = _nomeValido(
      nome,
      voci.where((x) => x.id != id).map((x) => x.nome),
      'voce',
    );
    return _mappaVoce(id, (v) => v.copyWith(nome: n));
  }

  /// La voce va in fondo al nuovo gruppo.
  Situazione spostaVoce(String id, Gruppo gruppo) {
    final v = voci.firstWhere((x) => x.id == id);
    if (v.gruppo == gruppo) return this;
    return Situazione(
      _inFondoAlGruppo(
        voci.where((x) => x.id != id).toList(),
        v.copyWith(gruppo: gruppo),
      ),
    );
  }

  Situazione aggiungiRiga(String voceId, Riga r) {
    final righe = _righe(voceId);
    final nome = _nomeValido(r.nome, righe.map((x) => x.nome), 'riga');
    return _mappaVoce(
      voceId,
      (v) => v.copyWith(
        righe: [
          ...righe,
          r.copyWith(nome: nome),
        ],
      ),
    );
  }

  Situazione rinominaRiga(String voceId, String rigaId, String nome) {
    final righe = _righe(voceId);
    final n = _nomeValido(
      nome,
      righe.where((x) => x.id != rigaId).map((x) => x.nome),
      'riga',
    );
    return _mappaVoce(
      voceId,
      (v) => v.copyWith(
        righe: [
          for (final r in righe) r.id == rigaId ? r.copyWith(nome: n) : r,
        ],
      ),
    );
  }

  Situazione modificaSaldoRiga(
    String voceId,
    String rigaId,
    int saldoCentesimi,
  ) => _mappaVoce(
    voceId,
    (v) => v.copyWith(
      righe: [
        for (final r in _righe(voceId))
          r.id == rigaId ? r.copyWith(saldoCentesimi: saldoCentesimi) : r,
      ],
    ),
  );

  Situazione eliminaRiga(String voceId, String rigaId) => _mappaVoce(
    voceId,
    (v) => v.copyWith(
      righe: [
        for (final r in _righe(voceId))
          if (r.id != rigaId) r,
      ],
    ),
  );

  List<Riga> _righe(String voceId) =>
      voci.firstWhere((x) => x.id == voceId).righe!;

  Situazione _mappaVoce(String id, Voce Function(Voce) f) =>
      Situazione([for (final v in voci) v.id == id ? f(v) : v]);

  static List<Voce> _inFondoAlGruppo(List<Voce> voci, Voce nuova) {
    final i = voci.lastIndexWhere((x) => x.gruppo == nuova.gruppo);
    return [...voci]..insert(i + 1, nuova);
  }

  /// Restituisce il nome senza spazi ai bordi, o lancia [ValidazioneException].
  static String _nomeValido(
    String nome,
    Iterable<String> esistenti,
    String cosa,
  ) {
    final n = nome.trim();
    if (n.isEmpty) {
      throw ValidazioneException('Il nome della $cosa non può essere vuoto');
    }
    if (esistenti.any((e) => e.trim().toLowerCase() == n.toLowerCase())) {
      throw ValidazioneException('Esiste già una $cosa con il nome "$n"');
    }
    return n;
  }
}
