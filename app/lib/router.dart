import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth.dart';
import 'ui/accesso_page.dart';
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
      GoRoute(path: '/', builder: (_, _) => const SituazionePage()),
      GoRoute(path: '/accesso', builder: (_, _) => const AccessoPage()),
    ],
  );
});
