import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/ui/app_theme.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrasto(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

void main() {
  test('AND-018 contrasto del tema', () {
    for (final fondo in [coloreFondo, coloreSuperficie]) {
      for (final testo in [
        coloreTesto,
        coloreSecondario,
        colorePositivo,
        coloreNegativo,
      ]) {
        expect(contrasto(testo, fondo), greaterThanOrEqualTo(4.5));
      }
    }
  });
}
