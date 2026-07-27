import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/application/session/notes_logout_service.dart';

void main() {
  test(
    'clears the offline session before authentication and invalidation',
    () async {
      final events = <String>[];
      final store = _SessionStore(
        const CachedSession(userId: '1', backendPreset: 'pi_wan'),
        onClear: () => events.add('offline-cleared'),
      );
      final service = NotesLogoutService(
        sessionStore: store,
        logoutAuthentication: () async {
          events.add('authentication-cleared');
        },
        invalidateOfflineSession: () {
          events.add('provider-invalidated');
        },
      );

      await service.logout();

      expect(await store.load(), isNull);
      expect(events, <String>[
        'offline-cleared',
        'authentication-cleared',
        'provider-invalidated',
      ]);
    },
  );

  test(
    'invalidates the offline session when authentication logout fails',
    () async {
      var invalidated = false;
      final store = _SessionStore(
        const CachedSession(userId: '1', backendPreset: 'pi_wan'),
      );
      final service = NotesLogoutService(
        sessionStore: store,
        logoutAuthentication: () => throw StateError('logout failed'),
        invalidateOfflineSession: () {
          invalidated = true;
        },
      );

      await expectLater(service.logout(), throwsStateError);

      expect(await store.load(), isNull);
      expect(invalidated, isTrue);
    },
  );
}

final class _SessionStore implements SessionStore {
  _SessionStore(this._session, {this.onClear});

  CachedSession? _session;
  final void Function()? onClear;

  @override
  Future<void> clear() async {
    _session = null;
    onClear?.call();
  }

  @override
  Future<CachedSession?> load() async => _session;

  @override
  Future<void> save(CachedSession session) async {
    _session = session;
  }
}
