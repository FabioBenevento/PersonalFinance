/// Importi in centesimi (int): lettura e scrittura in formato italiano.
const messaggioImportoNonValido = 'Importo non valido';

final _euro = RegExp(r'^€\s*');

final _importo = RegExp(
  r'^(?:(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?|(\d+)\.(\d{1,2}))$',
);

/// Centesimi, oppure null se [testo] non è un importo valido.
///
/// Accetta un prefisso facoltativo `€` seguito da spazi facoltativi, così il
/// testo prodotto da [scriviImporto] si rilegge sempre.
int? leggiImporto(String testo) {
  final m = _importo.firstMatch(testo.trim().replaceFirst(_euro, ''));
  if (m == null) return null;
  final intero = (m[1] ?? m[3])!.replaceAll('.', '');
  final decimali = (m[2] ?? m[4] ?? '').padRight(2, '0');
  return int.parse(intero) * 100 + int.parse(decimali);
}

String _migliaia(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');

String _decimali(int centesimi) {
  final c = centesimi % 100;
  return '${_migliaia(centesimi ~/ 100)},${c.toString().padLeft(2, '0')}';
}

String scriviImporto(int centesimi) => '€ ${_decimali(centesimi)}';

/// Formatta una percentuale espressa in centesimi di punto percentuale
/// (2500 = 25,00%); "—" se null (base zero).
String scriviPercentuale(int? centesimiDiPercento) =>
    centesimiDiPercento == null ? '—' : '${_decimali(centesimiDiPercento)}%';
