import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/auth/auth.dart';
import 'package:personal_finance/data/voci_providers.dart';
import 'package:personal_finance/main.dart';

import '../data/fake_voci_repository.dart';

class FakeGateway implements AuthGateway {
  FakeGateway({this.allowed = true});
  final bool allowed;
  final _uid = StreamController<String?>.broadcast(sync: true);
  String? _current;

  @override
  Stream<String?> uidChanges() async* {
    yield _current;
    yield* _uid.stream;
  }

  @override
  Future<bool> isAllowed(String uid) async => allowed;

  @override
  Future<void> signInWithGoogle() async => _uid.add(_current = 'u1');

  @override
  Future<void> signOut() async => _uid.add(_current = null);
}

Future<FakeGateway> pump(WidgetTester tester, {bool allowed = true}) async {
  final gateway = FakeGateway(allowed: allowed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authGatewayProvider.overrideWithValue(gateway),
        vociRepositoryProvider.overrideWithValue(FakeVociRepository()),
      ],
      child: const PersonalFinanceApp(),
    ),
  );
  await tester.pumpAndSettle();
  return gateway;
}

void main() {
  testWidgets('ACC-001 senza sessione si vede solo la pagina di accesso', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Accedi con Google'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('ACC-004 account non autorizzato', (tester) async {
    await pump(tester, allowed: false);
    await tester.tap(find.text('Accedi con Google'));
    await tester.pumpAndSettle();
    expect(find.text('Accesso non consentito per questo account'), findsOne);
    expect(find.text('Esci'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('ACC-009 uscita', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Accedi con Google'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.text('Esci'));
    await tester.pumpAndSettle();
    expect(find.text('Accedi con Google'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });
}
