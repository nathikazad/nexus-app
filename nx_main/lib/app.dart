import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/router.dart';

class NexusVoiceAssistantApp extends ConsumerStatefulWidget {
  const NexusVoiceAssistantApp({super.key});

  @override
  ConsumerState<NexusVoiceAssistantApp> createState() =>
      _NexusVoiceAssistantAppState();
}

class _NexusVoiceAssistantAppState
    extends ConsumerState<NexusVoiceAssistantApp> {
  String? _activeSocketSessionKey;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      if (!next.hasValue) return;

      final service = ref.read(bleBackgroundServiceProvider);
      final user = next.value;
      if (user == null) {
        if (_activeSocketSessionKey != null) {
          _activeSocketSessionKey = null;
          service.disconnectSocket();
        }
        return;
      }

      final urls = resolve(user.preset);
      final sessionKey = [
        urls.sockWs,
        user.userId,
        user.personalDomainId,
        user.homeDomainId,
      ].join('|');
      if (_activeSocketSessionKey == sessionKey) return;

      if (_activeSocketSessionKey != null) {
        service.disconnectSocket();
      }
      _activeSocketSessionKey = sessionKey;
      service.connectSocket(
        url: urls.sockWs,
        userId: user.userId,
        personalDomainId: user.personalDomainId,
        sharedDomainId: user.homeDomainId,
      );
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Nexus Voice Assistant',
      theme: buildNexusMainTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
