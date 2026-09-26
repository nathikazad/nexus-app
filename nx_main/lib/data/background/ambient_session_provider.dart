import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import '../../application/sessions/session_coordinator.dart';
import '../providers.dart';
import 'background_session_command.dart';

/// Auth-to-device composition lives here, not in the app widget.
final ambientSessionProvider = Provider<void>((ref) {
  final service = ref.read(bleBackgroundServiceProvider);
  final watch =
      !kIsWeb && Platform.isIOS ? ref.read(watchVoiceRelayProvider) : null;
  final coordinator = SessionCoordinator<User>(
    disconnectNecklace: service.disconnectSocket,
    configureWatch: (user) {
      watch?.configure(
        socketUrl: user == null ? null : resolve(user.preset).sockWs,
        userId: user?.userId,
        domainId: user?.domainId,
        authHeaders: user == null
            ? null
            : (forceRefresh) => nexusAuthHeaders(user.preset, user.sessionKey,
                forceRefresh: forceRefresh),
      );
      if (user != null) watch?.start();
    },
    connectNecklace: (user) {
      final urls = resolve(user.preset);
      service.connectSocket(
          url: urls.sockWs,
          telemetryHttpBaseUrl: urls.imageHttp,
          userId: user.userId,
          domainId: user.requiredDomainId,
          preset: user.preset,
          clientAppId: ref.read(nexusClientAppIdProvider));
    },
  );
  ref.listen<AsyncValue<User?>>(authProvider, (_, next) {
    if (!next.hasValue) return;
    final user = next.value;
    if (user == null || user.domainId == null) {
      coordinator.update(null, null);
      return;
    }
    final urls = resolve(user.preset);
    final config = BackgroundSessionCommand(
        url: urls.sockWs,
        telemetryHttpBaseUrl: urls.imageHttp,
        userId: user.userId,
        domainId: user.requiredDomainId,
        preset: user.preset,
        clientAppId: ref.read(nexusClientAppIdProvider));
    coordinator.update(config.identity, user);
  }, fireImmediately: true);
});
