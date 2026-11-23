@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/firebase_options.dart';

@JS('window.open')
external JSFunction get windowOpen;

@JS('window.open')
external set windowOpen(JSFunction value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebaseCoreWeb.registerWith(webPluginRegistrar);
  FirebaseAuthWeb.registerWith(webPluginRegistrar);

  test(
    'ACC-002 il gateway web avvia il popup Google con il vero SDK',
    () async {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      final originalOpen = windowOpen;
      var popupAttempts = 0;
      windowOpen = ((JSAny? url, JSAny? target, JSAny? features) {
        popupAttempts++;
        return null;
      }).toJS;
      addTearDown(() => windowOpen = originalOpen);

      await expectLater(
        FirebaseAuthGateway().signInWithGoogle(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'popup-blocked',
          ),
        ),
      );
      expect(popupAttempts, 1);
    },
  );
}
