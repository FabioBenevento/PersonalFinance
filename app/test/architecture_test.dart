import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _forbidden = RegExp(
  r'''^\s*(import|export)\s+['"]package:(flutter|firebase_[a-z_]*|cloud_firestore)/''',
  multiLine: true,
);

void main() {
  test('lib/domain does not import Flutter or Firebase', () {
    final dir = Directory('lib/domain');
    final files = dir.existsSync()
        ? dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
        : <File>[];
    final offenders = [
      for (final f in files)
        if (_forbidden.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('lib/domain does not import fl_chart', () {
    expect(_offenders('lib/domain', _chart), isEmpty);
  });

  test('lib/ui outside app_theme.dart has no Color( or Colors.', () {
    expect(_offenders('lib/ui', _colors, skip: 'app_theme.dart'), isEmpty);
  });
}

final _chart = RegExp(
  r'''^\s*(import|export)\s+['"]package:fl_chart/''',
  multiLine: true,
);
final _colors = RegExp(r'\b(Color\(|Colors\.)');

List<String> _offenders(String path, RegExp pattern, {String? skip}) {
  final dir = Directory(path);
  if (!dir.existsSync()) return [];
  return [
    for (final f in dir.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart') &&
          (skip == null || !f.path.endsWith(skip)) &&
          pattern.hasMatch(f.readAsStringSync()))
        f.path,
  ];
}
