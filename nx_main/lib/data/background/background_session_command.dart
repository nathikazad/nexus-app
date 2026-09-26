import 'package:nx_db/auth.dart';
import '../../application/sessions/session_identity.dart';

/// Typed foreground/background session boundary. Invalid input retires the old
/// session before the runtime refuses the new one.
class BackgroundSessionCommand {
  BackgroundSessionCommand(
      {required this.url,
      required this.telemetryHttpBaseUrl,
      required String userId,
      required int domainId,
      required this.preset,
      required String clientAppId})
      : identity = SessionIdentity(
            backend: '${preset.key}|$url',
            userId: userId,
            domainId: domainId,
            clientApp: clientAppId) {
    if (url.isEmpty) throw StateError('Socket URL is required.');
  }
  final String url;
  final String telemetryHttpBaseUrl;
  final BackendPreset preset;
  final SessionIdentity identity;
  String get userId => identity.userId;
  int get domainId => identity.domainId;
  String get clientAppId => identity.clientApp;
  Map<String, dynamic> toMap() => {
        'url': url,
        'telemetryHttpBaseUrl': telemetryHttpBaseUrl,
        'userId': userId,
        'domainId': domainId,
        'preset': preset.key,
        'clientAppId': clientAppId,
      };
  factory BackgroundSessionCommand.fromMap(Map<String, dynamic> map) =>
      BackgroundSessionCommand(
          url: map['url'] as String,
          telemetryHttpBaseUrl: map['telemetryHttpBaseUrl'] as String? ?? '',
          userId: map['userId'] as String,
          domainId: map['domainId'] as int,
          preset: BackendPreset.fromKey(map['preset'] as String?) ??
              (throw StateError('Backend required')),
          clientAppId: map['clientAppId'] as String);
}
