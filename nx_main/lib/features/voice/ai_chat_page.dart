import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/features/voice/voice_socket_controller.dart';
import 'package:nx_views/nx_views.dart';

class AiChatPage extends ConsumerWidget {
  const AiChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceSocketControllerProvider);
    return CurrentTranscriptChatPage(
      title: 'AI assistant',
      theme: const CurrentTranscriptChatTheme(
        accent: AppColors.orange600,
        background: AppColors.gray50,
        surface: Colors.white,
        inputBackground: AppColors.gray100,
        border: AppColors.gray100,
        textPrimary: AppColors.gray900,
        textSecondary: AppColors.gray600,
        textMuted: AppColors.gray400,
      ),
      liveMessages: [
        for (final message in voiceState.messages)
          CurrentTranscriptChatMessage(
            key: message.turnkey,
            text: message.text,
            fromUser: message.fromUser,
            links: [
              for (final link in message.links)
                CurrentTranscriptChatLink(
                  label: link.label,
                  url: link.url,
                  kind: link.kind,
                  routeName: link.routeName,
                ),
            ],
          ),
      ],
      onSend: ref.read(voiceSocketControllerProvider.notifier).sendTextMessage,
    );
  }
}
