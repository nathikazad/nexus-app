import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/app/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Restoring extends AuthController {
  final pending = Completer<User?>();
  @override
  Future<User?> build() => pending.future;
}

void main() {
  testWidgets(
    'a resolved empty session does not flash login while auth restores',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Restoring.new),
          activeOfflineSessionProvider.overrideWith((_) async => null),
        ],
      );
      final router = c.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.read(activeOfflineSessionProvider).isLoading, false);
      expect(c.read(authProvider).isLoading, true);
      expect(router.routeInformationProvider.value.uri.path, '/initializing');
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      c.dispose();
    },
  );
}
