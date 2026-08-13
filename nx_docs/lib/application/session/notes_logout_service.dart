import 'package:nx_docs/application/ports/session_store.dart';

typedef AuthenticationLogout = Future<void> Function();
typedef OfflineSessionInvalidator = void Function();

/// Ends the authenticated and cached-offline sessions without deleting the
/// account's downloaded Notes database.
final class NotesLogoutService {
  const NotesLogoutService({
    required this.sessionStore,
    required this.logoutAuthentication,
    required this.invalidateOfflineSession,
  });

  final SessionStore sessionStore;
  final AuthenticationLogout logoutAuthentication;
  final OfflineSessionInvalidator invalidateOfflineSession;

  Future<void> logout() async {
    await sessionStore.clear();
    try {
      await logoutAuthentication();
    } finally {
      invalidateOfflineSession();
    }
  }
}
