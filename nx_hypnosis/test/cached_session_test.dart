import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_auth/nx_auth.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_hypnosis/cached_session.dart';

class PendingAuth extends AuthController {
  final answer = Completer<User?>();
  @override
  Future<User?> build() => answer.future;
}

void main() {
  test(
    'saved account waits for auth and domain readiness, rejection clears it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = await hypnosisSessionStore();
      await store.save(
        const CachedSession(
          domainId: 1,
          serverId: 'nexus-primary',
          userId: '7',
          application: 'nx_hypnosis',
          route: 'hosted',
        ),
      );
      final auth = PendingAuth();
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => auth)],
      );
      addTearDown(container.dispose);
      final listener = container.listen(activeHypnosisUserProvider, (_, _) {});
      addTearDown(listener.close);
      expect(await container.read(activeHypnosisUserProvider.future), isNull);
      auth.answer.complete(null);
      await container.read(authProvider.future);
      expect(await container.read(activeHypnosisUserProvider.future), isNull);
      expect(await store.load(), isNull);
    },
  );
}
