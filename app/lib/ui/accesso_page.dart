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
          _ => FilledButton(
            onPressed: gateway.signInWithGoogle,
            child: const Text('Accedi con Google'),
          ),
        },
      ),
    );
  }
}
