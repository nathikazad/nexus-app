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

class _NexusVoiceAssistantAppState extends ConsumerState<NexusVoiceAssistantApp> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final user = next.value!;
        final urls = resolve(user.preset);
        ref.read(bleBackgroundServiceProvider).connectSocket(urls.sockWs);
      }
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
