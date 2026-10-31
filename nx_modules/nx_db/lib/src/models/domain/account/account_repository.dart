import 'account.dart';

/// Persistence for the current user's account row and account preferences.
abstract class AccountRepository {
  /// Current user's account row including `users.preferences`.
  Future<AccountProfile?> getCurrent();

  /// Replaces `users.preferences` for the authenticated user.
  Future<AccountProfile> updatePreference(
    AccountProfile account,
    Map<String, dynamic> preference,
  );
}
