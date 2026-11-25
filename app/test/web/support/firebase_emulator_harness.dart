import 'dart:convert';
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url, JSObject options);

extension type _Response(JSObject _) implements JSObject {
  external int get status;
}

class FirebaseEmulatorHarness {
  FirebaseEmulatorHarness._(this.app, this.auth, this.firestore);

  static const projectId = 'demo-personal-finance';
  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  String get uid => auth.currentUser!.uid;

  static Future<FirebaseEmulatorHarness> open() async {
    FirebaseCoreWeb.registerWith(webPluginRegistrar);
    FirebaseAuthWeb.registerWith(webPluginRegistrar);
    FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
    final app = await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:123456789:web:emulator',
        messagingSenderId: '123456789',
        projectId: projectId,
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 9099);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.useFirestoreEmulator('127.0.0.1', 8080);
    await auth.signInAnonymously();
    final harness = FirebaseEmulatorHarness._(app, auth, firestore);
    await harness._fixture('allowlist/${harness.uid}', 'PATCH', {});
    return harness;
  }

  // Administrative fixtures are confined to this local demo emulator.
  Future<void> _fixture(
    String path,
    String method, [
    Map<String, Object?>? body,
  ]) async {
    final response = await _fetch(
      'http://127.0.0.1:8080/v1/projects/$projectId/databases/(default)/documents/$path'
          .toJS,
      {
            'method': method,
            'headers': {
              'Authorization': 'Bearer owner',
              'Content-Type': 'application/json',
            },
            if (body != null) 'body': jsonEncode(body),
          }.jsify()!
          as JSObject,
    ).toDart;
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Fixture emulator $method $path: ${response.status}');
    }
  }

  Future<void> impostaSaldoRemoto(String id, int saldoCentesimi) => _fixture(
    'users/$uid/voci/$id?updateMask.fieldPaths=saldoCentesimi',
    'PATCH',
    {
      'fields': {
        'saldoCentesimi': {'integerValue': '$saldoCentesimi'},
      },
    },
  );

  /// Server-side write of [campi] (Firestore REST values) on a voce, as another device.
  Future<void> scriviCampiRemoti(
    String id,
    Map<String, Object?> campi,
  ) => _fixture(
    'users/$uid/voci/$id?${campi.keys.map((k) => 'updateMask.fieldPaths=$k').join('&')}',
    'PATCH',
    {'fields': campi},
  );

  /// Admin write (bypassing rules) of REST [campi] at [percorso], to seed the
  /// collections the client may not write, such as the broker generations.
  Future<void> scriviRemoto(String percorso, Map<String, Object?> campi) =>
      _fixture(percorso, 'PATCH', {'fields': campi});

  Future<void> eliminaRemoto(String percorso) => _fixture(percorso, 'DELETE');

  Future<void> close() async {
    await _fixture('users/$uid/voci/b', 'DELETE');
    await _fixture('users/$uid/fotografie/2026-11', 'DELETE');
    await _fixture('allowlist/$uid', 'DELETE');
    await auth.currentUser?.delete();
    await firestore.terminate();
    await app.delete();
  }
}
