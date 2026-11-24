import 'package:flutter/material.dart';

const coloreFondo = Color(0xFFF6F8F5);
const coloreTesto = Color(0xFF18312A);
const coloreSecondario = Color(0xFF50665D);
const coloreAzione = Color(0xFF215A42);
const coloreSelezione = Color(0xFFE7EEE7);
const coloreBordo = Color(0xFFD7E0D9);
const coloreSuperficie = Colors.white;
const stileCifre = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
);
final stileImporto = stileCifre;
final stileImportoPiccolo = stileCifre.copyWith(fontSize: 12);
final stileImportoSecondario = stileImportoPiccolo.copyWith(
  color: coloreSecondario,
);
final stileTotale = stileCifre.copyWith(
  fontSize: 30,
  fontWeight: FontWeight.bold,
);

final appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: coloreFondo,
  colorScheme: ColorScheme.fromSeed(seedColor: coloreAzione).copyWith(
    primary: coloreAzione,
    onSurface: coloreTesto,
    onSurfaceVariant: coloreSecondario,
    surface: Colors.white,
    surfaceContainerHighest: coloreSelezione,
    outlineVariant: coloreBordo,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: coloreTesto,
    foregroundColor: Colors.white,
    actionsIconTheme: IconThemeData(color: Colors.white),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  listTileTheme: const ListTileThemeData(dense: true, minVerticalPadding: 8),
  dividerTheme: const DividerThemeData(color: coloreBordo, space: 1),
);
