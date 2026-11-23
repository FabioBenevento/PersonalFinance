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
}
