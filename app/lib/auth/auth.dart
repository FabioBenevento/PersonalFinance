import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Authentication state of the app.
sealed class AuthState {
  const AuthState();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class NotAllowed extends AuthState {
  const NotAllowed();
}

/// The allowlist check failed for a transient reason (e.g. no network).
class VerificaFallita extends AuthState {
  const VerificaFallita();
}

class Allowed extends AuthState {
  const Allowed(this.uid);
  final String uid;
}

/// Seam of the authentication flow, replaced with a fake in widget tests.
abstract class AuthGateway {
  /// The signed-in user's uid, or null when signed out; emits on every change.
  Stream<String?> uidChanges();

  /// Whether `allowlist/{uid}` exists. A missing document is `false`; any
  /// other failure (network, unavailable...) is thrown as [FirebaseException].
  Future<bool> isAllowed(String uid);

  /// Starts the Google sign-in flow (popup on web).
  Future<void> signInWithGoogle();

  /// Signs the current user out.
  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  final _auth = FirebaseAuth.instance;

  @override
  Stream<String?> uidChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<bool> isAllowed(String uid) async {
    final doc = await FirebaseFirestore.instance.doc('allowlist/$uid').get();
    return doc.exists;
  }

  @override
  Future<void> signInWithGoogle() => kIsWeb
      ? _auth.signInWithPopup(GoogleAuthProvider())
      : _auth.signInWithProvider(GoogleAuthProvider());

  @override
  Future<void> signOut() => _auth.signOut();
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => FirebaseAuthGateway(),
);

final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final gateway = ref.watch(authGatewayProvider);
  await for (final uid in gateway.uidChanges()) {
    if (uid == null) {
      yield const SignedOut();
    } else {
      try {
        yield await gateway.isAllowed(uid) ? Allowed(uid) : const NotAllowed();
      } on FirebaseException {
        yield const VerificaFallita();
      }
    }
  }
});
