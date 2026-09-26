import 'dart:convert';

/// Immutable ownership of asynchronous work. No default domain is permitted.
class SessionIdentity {
  SessionIdentity(
      {required this.backend,
      required this.userId,
      required this.domainId,
      required this.clientApp}) {
    if (backend.isEmpty ||
        userId.isEmpty ||
        clientApp.isEmpty ||
        domainId <= 0) {
      throw StateError(
          'Backend, user, app and a positive domain are required.');
    }
  }
  final String backend;
  final String userId;
  final int domainId;
  final String clientApp;
  String get key => jsonEncode([backend, userId, domainId, clientApp]);
  @override
  bool operator ==(Object other) =>
      other is SessionIdentity && other.key == key;
  @override
  int get hashCode => key.hashCode;
}
