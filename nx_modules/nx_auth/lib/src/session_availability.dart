import 'package:oidc/oidc.dart';

/// The browser flow finished without an authenticated user.
final class AuthSignInCancelled implements Exception {
  const AuthSignInCancelled();

  @override
  String toString() => 'Sign-in was cancelled';
}

/// The provider returned a token which failed the library's validation.
final class AuthSignInValidationFailed implements Exception {
  const AuthSignInValidationFailed(this.reasons);
  final List<String> reasons;

  @override
  String toString() =>
      'Sign-in token validation failed (${reasons.join(', ')})';
}

/// Maps library validation diagnostics to fixed, credential-free categories.
String authValidationReason(String message) {
  final text = message.toLowerCase();
  for (final claim in [
    'azp',
    'at_hash',
    'c_hash',
    'auth_time',
    'nbf',
    'nonce',
  ]) {
    if (text.contains(claim)) return claim;
  }
  if (text.contains('audience')) return 'audience';
  if (text.contains('issuer')) return 'issuer';
  if (text.contains('expired')) return 'expired';
  if (text.contains('subject') || text.contains('`sub`')) return 'subject';
  if (text.contains('`iat`')) return 'issued_at';
  return 'other';
}

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
    if (error is OidcException) {
      if (error.kind == OidcTokenRefreshFailureKind.terminal) {
        throw const AuthSessionRejected();
      }
      if (error.kind == OidcTokenRefreshFailureKind.transient) {
        throw const AuthServiceUnavailable();
      }
    }
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
