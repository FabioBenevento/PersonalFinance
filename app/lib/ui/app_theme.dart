import 'package:flutter/material.dart';

const coloreFondo = Color(0xFF0E1513);
const coloreSuperficie = Color(0xFF141E1B);
const coloreTesto = Color(0xFFE7F0EC);
const coloreSecondario = Color(0xFF8FA69C);
const coloreBordo = Color(0xFF24332E);
const coloreAzione = Color(0xFF3DDC97);
const colorePositivo = Color(0xFF3DDC97);
const coloreNegativo = Color(0xFFFF7A6B);
const coloreSelezione = Color(0xFF1C2A26);
const coloreSuTesto = Color(0xFF0E1513);
const coloriSerieGrafici = [
  Color(0xFF3DDC97),
  Color(0xFF5AB8F0),
  Color(0xFFB48CF2),
  Color(0xFFF2C14E),
];
const raggio = 6.0;
const stileImporto = TextStyle(
  fontFamily: 'JetBrains Mono',
  fontFeatures: [FontFeature.tabularFigures()],
);
final stileImportoPiccolo = stileImporto.copyWith(fontSize: 12);
final stileImportoSecondario = stileImportoPiccolo.copyWith(
  color: coloreSecondario,
);
final stileTotale = stileImporto.copyWith(
  fontSize: 30,
  fontWeight: FontWeight.bold,
);

final appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: coloreFondo,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: coloreAzione,
        brightness: Brightness.dark,
      ).copyWith(
        primary: coloreAzione,
        onPrimary: coloreSuTesto,
        secondary: coloriSerieGrafici[1],
        tertiary: coloriSerieGrafici[2],
        error: coloreNegativo,
        surface: coloreSuperficie,
        onSurface: coloreTesto,
        onSurfaceVariant: coloreSecondario,
        surfaceContainerHighest: coloreSelezione,
        outline: coloreBordo,
        outlineVariant: coloreBordo,
      ),
  appBarTheme: const AppBarTheme(
    backgroundColor: coloreSuperficie,
    foregroundColor: coloreTesto,
    actionsIconTheme: IconThemeData(color: coloreTesto),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(raggio),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(raggio),
      ),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: coloreSuperficie,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: coloreBordo),
      borderRadius: BorderRadius.circular(raggio),
    ),
  ),
  listTileTheme: const ListTileThemeData(dense: true, minVerticalPadding: 8),
  dividerTheme: const DividerThemeData(color: coloreBordo, space: 1),
);
