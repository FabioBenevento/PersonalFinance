import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class AuthState {
  const AuthState();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class NotAllowed extends AuthState {
  const NotAllowed();
}

class Allowed extends AuthState {
  const Allowed(this.uid);
  final String uid;
}

/// Seam of the authentication flow, replaced with a fake in widget tests.
abstract class AuthGateway {
  Stream<String?> uidChanges();
  Future<bool> isAllowed(String uid);
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  final _auth = FirebaseAuth.instance;

  @override
  Stream<String?> uidChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<bool> isAllowed(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.doc('allowlist/$uid').get();
      return doc.exists;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<void> signInWithGoogle() =>
      _auth.signInWithProvider(GoogleAuthProvider());

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
      yield await gateway.isAllowed(uid) ? Allowed(uid) : const NotAllowed();
    }
  }
});
