import 'package:personal_finance/domain/importo.dart';
import 'package:personal_finance/domain/voce.dart';

/// Preparazione bloccata; [message] indica voce, anno e mese.
class PreparazioneException implements Exception {
  const PreparazioneException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _Nome {
  const _Nome(this.id, this.nome, this.gruppo, this.categoria);

  final String id;
  final String nome;
  final Gruppo gruppo;
  final CategoriaInvestimento? categoria;
}

/// Tabella `tabella_nomi.json`: etichetta del foglio → voce.
class TabellaNomi {
  TabellaNomi._(this._voci, this._totali, this._ignorare);

  factory TabellaNomi.fromJson(Map<String, dynamic> json) => TabellaNomi._(
    {
      for (final e in (json['voci'] as Map<String, dynamic>).entries)
        e.key: _Nome(
          e.value['id'] as String,
          e.value['nome'] as String,
          Gruppo.values.byName(e.value['gruppo'] as String),
          e.value['categoria'] == null
              ? null
              : CategoriaInvestimento.values.byName(
                  e.value['categoria'] as String,
                ),
        ),
    },
    (json['totali'] as List).cast<String>().toSet(),
    (json['ignorare'] as List).cast<String>(),
  );

  /// Righe della tabella, per il file di revisione.
  List<(String, String, Gruppo, CategoriaInvestimento?)> get elenco => [
    for (final e in _voci.entries)
      (e.key, e.value.nome, e.value.gruppo, e.value.categoria),
  ];

  final Map<String, _Nome> _voci;
  final Set<String> _totali;
  final List<String> _ignorare;
}

/// Voci di un foglio mensile nell'ordine del foglio e totali scritti nel foglio.
class FoglioMensile {
  const FoglioMensile(this.voci, this.totali);

  final List<Voce> voci;

  /// Etichetta del totale → centesimi, per il confronto con le somme ricalcolate.
  final Map<String, int> totali;
}

/// Classifica ogni riga del foglio per etichetta (colonna A, saldo in B).
FoglioMensile parseFoglio({
  required List<List<Object?>> celle,
  required int anno,
  required int mese,
  required TabellaNomi tabella,
}) {
  final quando = '$anno-${mese.toString().padLeft(2, '0')}';
  final voci = <Voce>[];
  final totali = <String, int>{};
  for (final riga in celle) {
    final etichetta = riga.isEmpty ? '' : '${riga[0] ?? ''}'.trim();
    if (etichetta.isEmpty) continue;
    final voce = tabella._voci[etichetta];
    final totale = tabella._totali.contains(etichetta);
    if (voce == null && !totale && tabella._ignorare.any(etichetta.contains)) {
      continue;
    }
    if (voce == null && !totale) {
      throw PreparazioneException('Voce sconosciuta "$etichetta" ($quando)');
    }
    final testo = riga.length > 1 ? '${riga[1] ?? ''}' : '';
    final saldo = leggiImporto(testo);
    if (saldo == null) {
      throw PreparazioneException(
        'Importo illeggibile "$testo" per "$etichetta" ($quando)',
      );
    }
    if (voce == null) {
      totali[etichetta] = saldo;
      continue;
    }
    if (voce.gruppo == Gruppo.investimenti && voce.categoria == null) {
      throw PreparazioneException(
        'Investimento "$etichetta" senza categoria ($quando)',
      );
    }
    voci.add(
      Voce.semplice(
        id: voce.id,
        nome: voce.nome,
        gruppo: voce.gruppo,
        categoria: voce.categoria,
        saldoCentesimi: saldo,
      ),
    );
  }
  return FoglioMensile(voci, totali);
}
