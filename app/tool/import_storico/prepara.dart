import 'dart:convert';
import 'dart:io';

import 'package:personal_finance/data/fotografia_documento.dart';
import 'package:personal_finance/data/fotografia_mapper.dart';
import 'package:personal_finance/domain/fotografia_mensile.dart';
import 'package:personal_finance/domain/importo.dart';
import 'package:personal_finance/domain/mese.dart';
import 'package:personal_finance/domain/voce.dart';

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
    // Ogni documento generato deve essere rileggibile dall'app.
    fotografiaFromMap(id, jsonDecode(jsonEncode(fotografiaToDocumento(f))));
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

String scriviRevisione(Preparazione p, TabellaNomi tabella) {
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
  return b.toString();
}

/// Legge `<base>/dati/grezzi` e scrive `fotografie.json` e `revisione.md` in `<base>/dati`.
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
  const enc = JsonEncoder.withIndent('  ');
  File('${base.path}/dati/fotografie.json')
      .writeAsStringSync(enc.convert(documenti(p)));
  File('${base.path}/dati/revisione.md')
      .writeAsStringSync(scriviRevisione(p, tabella));
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
