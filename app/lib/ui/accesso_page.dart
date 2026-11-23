import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';

class AccessoPage extends ConsumerWidget {
  const AccessoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateway = ref.watch(authGatewayProvider);
    final state = ref.watch(authStateProvider).value;
    return Scaffold(
      body: Center(
        child: switch (state) {
          null => const CircularProgressIndicator(),
          NotAllowed() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Accesso non consentito per questo account'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: gateway.signOut,
                child: const Text('Esci'),
              ),
            ],
          ),
          VerificaFallita() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossibile verificare l\'accesso'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(authStateProvider),
                child: const Text('Riprova'),
              ),
              TextButton(onPressed: gateway.signOut, child: const Text('Esci')),
            ],
          ),
          _ => FilledButton(
            onPressed: () async {
              try {
                await gateway.signInWithGoogle();
              } on FirebaseAuthException catch (error) {
                if (!context.mounted) return;
                final message = error.code == 'popup-blocked'
                    ? 'Consenti i popup del browser e riprova.'
                    : 'Accesso con Google non riuscito. Riprova.';
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              }
            },
            child: const Text('Accedi con Google'),
          ),
        },
      ),
    );
  }
}
