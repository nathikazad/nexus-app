import 'dart:convert';

/// Immutable ownership of asynchronous work. No default domain is permitted.
abstract interface class SessionKey {
  String get key;
}

class SessionIdentity implements SessionKey {
  SessionIdentity(
      {required this.backend,
      required this.userId,
      required this.domainId,
      required this.clientId}) {
    if (backend.isEmpty ||
        userId.isEmpty ||
        clientId.isEmpty ||
        domainId <= 0) {
      throw StateError(
          'Backend, user, app and a positive domain are required.');
    }
  }
  final String backend;
  final String userId;
  final int domainId;
  final String clientId;
  String get key => jsonEncode([backend, userId, domainId, clientId]);
  @override
  bool operator ==(Object other) =>
      other is SessionIdentity && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

/// A device relay belongs to an authenticated user, not an app's selected domain.
class AmbientSessionIdentity implements SessionKey {
  AmbientSessionIdentity(
      {required this.backend, required this.userId, required this.clientId}) {
    if (backend.isEmpty || userId.isEmpty || clientId.isEmpty) {
      throw StateError('Backend, user and app are required.');
    }
  }
  final String backend;
  final String userId;
  final String clientId;
  @override
  String get key => jsonEncode(['ambient', backend, userId, clientId]);
  @override
  bool operator ==(Object other) =>
      other is AmbientSessionIdentity && other.key == key;
  @override
  int get hashCode => key.hashCode;
}
