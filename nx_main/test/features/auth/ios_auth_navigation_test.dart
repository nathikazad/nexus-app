import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/features/auth/ios_auth_navigation.dart';
import 'package:nexus_voice_assistant/router.dart';
import 'package:flutter/foundation.dart';

class SignedInWithoutDomain extends AuthController {
  @override
  Future<User?> build() async =>
      User(userId: '7', preset: BackendPreset.hosted);
}

class ControlledAuth extends AuthController {
  @override
  Future<User?> build() async => null;

  void startLogin() => state = const AsyncLoading();
  void finishLogin() =>
      state = AsyncData(User(userId: '7', preset: BackendPreset.hosted));
}

void main() {
  test('iOS keeps the same router throughout the native callback transaction',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(ControlledAuth.new),
      appBootstrapProvider.overrideWith((_) async {}),
    ]);
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    await container.read(appBootstrapProvider.future);
    final router = container.read(routerProvider);
    final auth = container.read(authProvider.notifier) as ControlledAuth;
    auth.startLogin();
    expect(container.read(routerProvider), same(router));
    auth.finishLogin();
    expect(container.read(routerProvider), same(router));
  });
  test(
      'callback wait preserves login; completion enters the app only with a domain',
      () {
    expect(
        iosAuthRedirect(
            location: '/login',
            bootstrapping: true,
            status: AppStatus.initializing),
        isNull);
    expect(
        iosAuthRedirect(
            location: '/models/1',
            bootstrapping: true,
            status: AppStatus.initializing),
        '/splash');
    expect(
        iosAuthRedirect(
            location: '/splash',
            bootstrapping: false,
            status: AppStatus.selectingDomain),
        '/login');
    expect(
        iosAuthRedirect(
            location: '/models/1',
            bootstrapping: false,
            status: AppStatus.selectingDomain),
        '/login');
    expect(
        iosAuthRedirect(
            location: '/login',
            bootstrapping: false,
            status: AppStatus.authenticated),
        '/');
    expect(
        iosAuthRedirect(
            location: '/models/1',
            bootstrapping: false,
            status: AppStatus.authenticated),
        isNull);
    expect(
        iosAuthRedirect(
            location: '/login',
            bootstrapping: false,
            status: AppStatus.unauthenticated),
        isNull);
  });

  testWidgets(
      'completed identity with multiple domains shows picker, not login',
      (tester) async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(SignedInWithoutDomain.new),
      appBootstrapProvider.overrideWith((_) async {}),
      domainLoaderProvider.overrideWithValue((_) async => const [
            DomainMembership(id: 1, name: 'Personal', role: 'owner'),
            DomainMembership(id: 2, name: 'Home', role: 'member'),
          ]),
    ]);
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    await container.read(appBootstrapProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: container.read(routerProvider)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Choose a domain'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
}
