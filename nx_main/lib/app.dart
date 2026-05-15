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

class _NexusVoiceAssistantAppState extends ConsumerState<NexusVoiceAssistantApp>
    with WidgetsBindingObserver {
  String? _activeSocketSessionKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(bleBackgroundServiceProvider).flushGpsBacklog();
    }
  }

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
      ].join('|');
      if (_activeSocketSessionKey == sessionKey) return;

      if (_activeSocketSessionKey != null) {
        service.disconnectSocket();
      }
      _activeSocketSessionKey = sessionKey;
      service.connectSocket(
        url: urls.sockWs,
        telemetryHttpBaseUrl: urls.imageHttp,
        userId: user.userId,
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
