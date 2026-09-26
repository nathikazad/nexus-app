import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

class _NexusVoiceAssistantAppState extends ConsumerState<NexusVoiceAssistantApp>
    with WidgetsBindingObserver {
  String? _activeSocketSessionKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(bleBackgroundServiceProvider)
          .updateAppLifecycleState(AppLifecycleState.resumed);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(bleBackgroundServiceProvider).updateAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      if (!next.hasValue) return;

      final service = ref.read(bleBackgroundServiceProvider);
      final watchRelay =
          !kIsWeb && Platform.isIOS ? ref.read(watchVoiceRelayProvider) : null;
      final user = next.value;
      if (user == null || user.domainId == null) {
        _activeSocketSessionKey = null;
        service.disconnectSocket();
        watchRelay?.configure(
          socketUrl: null,
          userId: null,
          domainId: null,
          authHeaders: null,
        );
        return;
      }

      final urls = resolve(user.preset);
      final sessionKey = [
        urls.sockWs,
        user.sessionKey,
      ].join('|');
      if (_activeSocketSessionKey == sessionKey) return;

      if (_activeSocketSessionKey != null) {
        service.disconnectSocket();
      }
      _activeSocketSessionKey = sessionKey;
      watchRelay
        ?..configure(
          socketUrl: urls.sockWs,
          userId: user.userId,
          domainId: user.requiredDomainId,
          authHeaders: (forceRefresh) => nexusAuthHeaders(
            user.preset,
            user.sessionKey,
            forceRefresh: forceRefresh,
          ),
        )
        ..start();
      service.connectSocket(
        url: urls.sockWs,
        telemetryHttpBaseUrl: urls.imageHttp,
        userId: user.userId,
        domainId: user.requiredDomainId,
        preset: user.preset,
        clientAppId: ref.read(nexusClientAppIdProvider),
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
