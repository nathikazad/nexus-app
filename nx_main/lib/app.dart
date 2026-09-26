import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data/background/ambient_session_provider.dart';
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
    ref.watch(ambientSessionProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Nexus Voice Assistant',
      theme: buildNexusMainTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
