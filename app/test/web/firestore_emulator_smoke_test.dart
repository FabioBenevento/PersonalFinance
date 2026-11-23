@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firebase_emulator_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseEmulatorHarness harness;
  setUpAll(() async => harness = await FirebaseEmulatorHarness.open());
  tearDownAll(() async => harness.close());

  test('FOT-019 proprietario autorizzato legge dal server', () async {
    final document = harness.firestore.doc(
      'users/${harness.uid}/fotografie/2026-11',
    );
    await document.set({'revisione': 1, 'voci': <Object>[]});
    final saved = await document.get(const GetOptions(source: Source.server));
    expect(saved.data(), {'revisione': 1, 'voci': <Object>[]});
    expect(saved.metadata.isFromCache, isFalse);
  });

  test('FOT-019 altro proprietario rifiutato dal server', () async {
    await expectLater(
      harness.firestore
          .doc('users/altro-proprietario/fotografie/2026-11')
          .get(const GetOptions(source: Source.server)),
      throwsA(
        isA<FirebaseException>().having(
          (error) => error.code,
          'code',
          'permission-denied',
        ),
      ),
    );
  });
}
