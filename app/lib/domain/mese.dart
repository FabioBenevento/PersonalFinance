import 'voce.dart';

class Mese implements Comparable<Mese> {
  Mese(this.anno, this.mese) {
    if (anno < 1 || anno > 9999 || mese < 1 || mese > 12) {
      throw const ValidazioneException('Mese non valido');
    }
  }

  factory Mese.fromId(String id) {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(id)) {
      throw const ValidazioneException('Mese non valido');
    }
    return Mese(int.parse(id.substring(0, 4)), int.parse(id.substring(5)));
  }

  final int anno;
  final int mese;

  String get id =>
      '${anno.toString().padLeft(4, '0')}-${mese.toString().padLeft(2, '0')}';

  void valida(DateTime oggi) {
    if (compareTo(Mese(oggi.year, oggi.month)) > 0) {
      throw const ValidazioneException('Non puoi salvare un mese futuro');
    }
  }

  @override
  int compareTo(Mese other) => id.compareTo(other.id);

  @override
  bool operator ==(Object other) =>
      other is Mese && anno == other.anno && mese == other.mese;

  @override
  int get hashCode => Object.hash(anno, mese);
}
