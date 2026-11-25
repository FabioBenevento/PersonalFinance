import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth.dart';
import 'data/voci_providers.dart';
import 'ui/accesso_page.dart';
import 'ui/andamento_page.dart';
import 'ui/broker_page.dart';
import 'ui/fotografie_page.dart';
import 'ui/situazione_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final allowed = ref.read(authStateProvider).value is Allowed;
      final onAccesso = state.matchedLocation == '/accesso';
      if (!allowed) return onAccesso ? null : '/accesso';
      return onAccesso ? '/' : null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Avvio()),
      GoRoute(path: '/fotografie', builder: (_, _) => const FotografiePage()),
      GoRoute(
        path: '/fotografie/:mese',
        builder: (_, state) =>
            FotografiePage(meseId: state.pathParameters['mese']),
      ),
      GoRoute(path: '/andamento', builder: (_, _) => const AndamentoPage()),
      GoRoute(path: '/broker', builder: (_, _) => const BrokerPage()),
      GoRoute(path: '/accesso', builder: (_, _) => const AccessoPage()),
    ],
  );
});

/// Shows an indicator while the one-time initial load runs, then the Situazione.
class _Avvio extends ConsumerWidget {
  const _Avvio();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(inizializzazioneProvider)) {
        AsyncData() => const SituazionePage(),
        AsyncError() => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => ref.invalidate(inizializzazioneProvider),
              child: const Text('Caricamento non riuscito, riprova'),
            ),
          ),
        ),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      };
}
