import 'dart:convert';
import 'dart:io';

import 'package:personal_finance/data/fotografia_documento.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/importo.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';
import 'package:personal_finance/domain/voci_iniziali.dart';

import 'parser_foglio.dart';

const _nomiGruppo = {
  Gruppo.salvadanaio: 'Salvadanaio',
  Gruppo.liquidita: 'Liquidità',
  Gruppo.investimenti: 'Investimenti',
};

/// Differenza tra un totale scritto nel foglio e quello ricalcolato.
class Differenza {
  const Differenza(this.mese, this.etichetta, this.foglio, this.ricalcolato);

  final String mese;
  final String etichetta;
  final int foglio;
  final int ricalcolato;
}

/// Esito della preparazione: documenti da caricare, mesi saltati e differenze.
class Preparazione {
  final fotografie = <String, FotografiaMensile>{};
  final saltati = <String, String>{};
  final differenze = <Differenza>[];
}

/// Prepara i mesi grezzi (`YYYY-MM` → `{valido, celle}`); ferma tutto al primo errore.
Preparazione preparaMesi(
  Map<String, Map<String, dynamic>> grezzi,
  TabellaNomi tabella,
) {
  final p = Preparazione();
  for (final id in grezzi.keys.toList()..sort()) {
    final mese = Mese.fromId(id);
    final grezzo = grezzi[id]!;
    if ('${grezzo['valido'] ?? ''}'.trim().toUpperCase() == 'NO') {
      p.saltati[id] = 'Valido = NO';
      continue;
    }
    final celle = [
      for (final r in grezzo['celle'] as List) (r as List).cast<Object?>(),
    ];
    if (celle.every((r) => r.length < 2 || '${r[1] ?? ''}'.trim().isEmpty)) {
      p.saltati[id] = 'foglio vuoto';
      continue;
    }
    final foglio = parseFoglio(
      celle: celle,
      anno: mese.anno,
      mese: mese.mese,
      tabella: tabella,
    );
    if (foglio.voci.isEmpty) {
      p.saltati[id] = 'foglio vuoto';
      continue;
    }
    final f = FotografiaMensile(mese: mese, voci: foglio.voci);
    final s = f.situazione;
    if (!s.classificazioneCompleta) {
      throw PreparazioneException('Investimenti non classificati ($id)');
    }
    for (final e in foglio.totali.entries) {
      final l = e.key.toLowerCase();
      final gruppo = Gruppo.values
          .where(
            (g) => l.contains(_nomiGruppo[g]!.toLowerCase().substring(0, 6)),
          )
          .firstOrNull;
      final ricalcolato = gruppo == null ? s.totale : s.totaleGruppo(gruppo);
      if (e.value != ricalcolato) {
        p.differenze.add(Differenza(id, e.key, e.value, ricalcolato));
      }
    }
    p.fotografie[id] = f;
  }
  return p;
}

/// Documenti `fotografie.json`: `YYYY-MM` → schema 2 senza `salvataIl`.
Map<String, Object?> documenti(Preparazione p) => {
  for (final e in p.fotografie.entries) e.key: fotografiaToDocumento(e.value),
};

/// Saldo di una voce attuale; [righe] (ID riga → nome e saldo) solo per le voci con dettaglio.
class SaldoVoce {
  SaldoVoce(this.nome, this.saldo, [this.righe]);

  final String nome;
  final int saldo;
  final Map<String, ({String nome, int saldo})>? righe;
}

int _importoPortafoglio(List r, String contesto) {
  final testo = r.length > 1 ? '${r[1] ?? ''}' : '';
  return leggiImporto(testo) ??
      (throw PreparazioneException(
        'Importo illeggibile "$testo" per "${r[0]}" ($contesto)',
      ));
}

/// Saldi di oggi dal grezzo del foglio "Portafoglio" (`situazione` e `dettagli`
/// per voce con dettaglio), per ID voce; ferma tutto se una voce o riga non è
/// riconducibile alle voci attuali.
Map<String, SaldoVoce> preparaSaldiOggi(
  Map<String, dynamic> grezzo,
  TabellaNomi tabella,
) {
  const dove = 'Portafoglio';
  final attuali = {for (final v in vociIniziali) v.id: v};
  final out = <String, SaldoVoce>{};
  final dettagli = (grezzo['dettagli'] as Map? ?? {}).cast<String, List>();
  for (final r in grezzo['situazione'] as List) {
    final riga = (r as List).cast<Object?>();
    final etichetta = riga.isEmpty ? '' : '${riga[0] ?? ''}'.trim();
    if (etichetta.isEmpty || tabella.ignorata(etichetta)) continue;
    final nome = tabella.voce(etichetta);
    final voce = nome == null ? null : attuali[nome.id];
    if (voce == null || voce.nome != nome!.nome) {
      throw PreparazioneException(
        'Voce non riconducibile "$etichetta" ($dove)',
      );
    }
    if (voce.righe == null) {
      out[voce.id] = SaldoVoce(voce.nome, _importoPortafoglio(riga, dove));
      continue;
    }
    final righe = <String, ({String nome, int saldo})>{};
    for (final d in dettagli[voce.nome] ?? const []) {
      final dr = (d as List).cast<Object?>();
      final n = dr.isEmpty ? '' : '${dr[0] ?? ''}'.trim();
      final id = voce.righe!.where((x) => x.nome == n).firstOrNull?.id;
      if (id == null) {
        throw PreparazioneException(
          'Riga non riconducibile "$n" di "${voce.nome}" ($dove)',
        );
      }
      righe[id] = (
        nome: n,
        saldo: _importoPortafoglio(dr, '${voce.nome}, $dove'),
      );
    }
    out[voce.id] = SaldoVoce(
      voce.nome,
      righe.values.fold(0, (a, r) => a + r.saldo),
      righe,
    );
  }
  for (final k in dettagli.keys) {
    if (!out.values.any((v) => v.nome == k && v.righe != null)) {
      throw PreparazioneException('Dettaglio non riconducibile "$k" ($dove)');
    }
  }
  return out;
}

/// Documento `saldi_oggi.json`: ID voce → nome atteso e saldo (o righe).
Map<String, Object?> documentoSaldiOggi(Map<String, SaldoVoce> saldi) => {
  for (final e in saldi.entries)
    e.key: {
      'nome': e.value.nome,
      if (e.value.righe == null)
        'saldoCentesimi': e.value.saldo
      else
        'righe': {
          for (final r in e.value.righe!.entries)
            r.key: {'nome': r.value.nome, 'saldoCentesimi': r.value.saldo},
        },
    },
};

String scriviRevisione(
  Preparazione p,
  TabellaNomi tabella, [
  Map<String, SaldoVoce>? saldiOggi,
]) {
  final b =
      StringBuffer('# Revisione import storico\n\n## Tabella dei nomi\n\n')
        ..writeln('| Etichetta | Nome | Gruppo | Categoria |')
        ..writeln('|---|---|---|---|');
  for (final (etichetta, nome, gruppo, categoria) in tabella.elenco) {
    b.writeln(
      '| $etichetta | $nome | ${_nomiGruppo[gruppo]} | ${categoria?.name ?? ''} |',
    );
  }
  b.writeln('\n## Mesi importati');
  for (final f in p.fotografie.values) {
    final s = f.situazione;
    b
      ..writeln('\n### ${f.mese.id}\n')
      ..writeln('| Voce | Gruppo | Categoria | Saldo |')
      ..writeln('|---|---|---|---|');
    for (final v in f.voci) {
      b.writeln(
        '| ${v.nome} | ${_nomiGruppo[v.gruppo]} | ${v.categoria?.name ?? ''} | ${scriviImporto(v.saldoCentesimi)} |',
      );
    }
    b.writeln(
      '\nSomme: ${[for (final g in Gruppo.values) '${_nomiGruppo[g]} ${scriviImporto(s.totaleGruppo(g))}'].join(', ')}; Totale ricalcolato ${scriviImporto(s.totale)}',
    );
  }
  b.writeln('\n## Differenze con i totali dei fogli\n');
  if (p.differenze.isEmpty) b.writeln('Nessuna.');
  for (final d in p.differenze) {
    b.writeln(
      '- ${d.mese} ${d.etichetta}: foglio ${scriviImporto(d.foglio)}, ricalcolato ${scriviImporto(d.ricalcolato)}, differenza ${d.foglio - d.ricalcolato < 0 ? '-' : ''}${scriviImporto((d.foglio - d.ricalcolato).abs())}',
    );
  }
  b.writeln('\n## Mesi saltati\n');
  if (p.saltati.isEmpty) b.writeln('Nessuno.');
  for (final e in p.saltati.entries) {
    b.writeln('- ${e.key}: ${e.value}');
  }
  if (saldiOggi != null) {
    b
      ..writeln('\n## Saldi di oggi\n')
      ..writeln('| Voce | Saldo |')
      ..writeln('|---|---|');
    for (final v in saldiOggi.values) {
      b.writeln('| ${v.nome} | ${scriviImporto(v.saldo)} |');
      for (final r in v.righe?.values ?? const <({String nome, int saldo})>[]) {
        b.writeln('| - ${r.nome} | ${scriviImporto(r.saldo)} |');
      }
    }
    b.writeln(
      '\nTotale ${scriviImporto(saldiOggi.values.fold(0, (a, v) => a + v.saldo))}',
    );
  }
  return b.toString();
}

/// Legge `<base>/dati/grezzi` e scrive `fotografie.json`, `revisione.md` e, con `portafoglio.json`, `saldi_oggi.json` in `<base>/dati`.
void preparaCartella(Directory base) {
  final tabella = TabellaNomi.fromJson(
    jsonDecode(File('${base.path}/tabella_nomi.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final nome = RegExp(r'^(\d{4}-\d{2})\.json$');
  final grezzi = <String, Map<String, dynamic>>{};
  for (final f in Directory('${base.path}/dati/grezzi').listSync()) {
    final m = nome.firstMatch(f.uri.pathSegments.last);
    if (f is File && m != null) {
      grezzi[m[1]!] = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    }
  }
  final p = preparaMesi(grezzi, tabella);
  final port = File('${base.path}/dati/grezzi/portafoglio.json');
  final saldi = port.existsSync()
      ? preparaSaldiOggi(
          jsonDecode(port.readAsStringSync()) as Map<String, dynamic>,
          tabella,
        )
      : null;
  const enc = JsonEncoder.withIndent('  ');
  File('${base.path}/dati/fotografie.json')
      .writeAsStringSync(enc.convert(documenti(p)));
  File('${base.path}/dati/revisione.md')
      .writeAsStringSync(scriviRevisione(p, tabella, saldi));
  if (saldi != null) {
    File('${base.path}/dati/saldi_oggi.json')
        .writeAsStringSync(enc.convert(documentoSaldiOggi(saldi)));
  }
}

void main(List<String> args) {
  try {
    preparaCartella(
      Directory(args.isEmpty ? 'tool/import_storico' : args.first),
    );
  } on PreparazioneException catch (e) {
    stderr.writeln('Preparazione bloccata: $e');
    exitCode = 1;
  }
}
