import 'package:oidc/oidc.dart';

/// Authentication could not be checked. This is not an authorization grant.
final class AuthServiceUnavailable implements Exception {
  const AuthServiceUnavailable();

  @override
  String toString() => 'Authentication service is unavailable';
}

final class AuthSessionRejected implements Exception {
  const AuthSessionRejected();

  @override
  String toString() => 'Sign in again to access this account';
}

/// Translate transport failures at the authentication boundary. Unknown and
/// validation errors must not silently enable access to a cached account.
Future<T> withAuthAvailability<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } catch (error) {
    final type = OidcOfflineAuthErrorHandler.categorizeError(error);
    if (type == OfflineAuthErrorType.authenticationError) {
      throw const AuthSessionRejected();
    }
    if (type == OfflineAuthErrorType.networkUnavailable ||
        type == OfflineAuthErrorType.networkTimeout ||
        type == OfflineAuthErrorType.serverError) {
      throw const AuthServiceUnavailable();
    }
    rethrow;
  }
}
