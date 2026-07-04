import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/core/theme/app_theme.dart';
import 'package:nexus_voice_assistant/data/watch/watch_bridge_service.dart';
import 'package:nexus_voice_assistant/features/data_browser/data_page.dart';
import 'package:nexus_voice_assistant/features/hardware/hardware_page.dart';
import 'package:nexus_voice_assistant/features/logs/log_viewer_page.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/models_page.dart';
import 'package:nexus_voice_assistant/features/voice/ai_chat_page.dart';
import 'package:nexus_voice_assistant/features/voice/voice_listening_overlay.dart';
import 'package:nexus_voice_assistant/features/voice/voice_socket_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  StreamSubscription<String>? _watchMessageSubscription;
  StreamSubscription<WatchAudioPacket>? _watchAudioSubscription;
  StreamSubscription<WatchAudioEOF>? _watchEOFSubscription;

  @override
  void initState() {
    super.initState();
    _setupWatchListeners();
  }

  void _setupWatchListeners() {
    if (!Platform.isIOS) return;

    _watchMessageSubscription =
        WatchBridgeService.instance.messageStream.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('From Watch: $message'),
            backgroundColor: Colors.deepPurple,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _watchMessageSubscription?.cancel();
    _watchAudioSubscription?.cancel();
    _watchEOFSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceSocketControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: const [
              HardwarePage(),
              ModelsPage(),
              LogViewerPage(),
              DataPage(),
            ],
          ),
          if (voiceState.overlayVisible) const VoiceListeningOverlay(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
        onAiTap: () {
          Navigator.of(context).push<void>(
            PageRouteBuilder<void>(
              transitionDuration: const Duration(milliseconds: 220),
              pageBuilder: (_, __, ___) => const AiChatPage(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },
        onAiHoldStart: () {
          unawaited(
            ref.read(voiceSocketControllerProvider.notifier).startRecording(),
          );
        },
        onAiHoldEnd: () {
          unawaited(
            ref.read(voiceSocketControllerProvider.notifier).stopRecording(),
          );
        },
        voiceState: voiceState,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onChanged,
    required this.onAiTap,
    required this.onAiHoldStart,
    required this.onAiHoldEnd,
    required this.voiceState,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onAiTap;
  final VoidCallback onAiHoldStart;
  final VoidCallback onAiHoldEnd;
  final VoiceSocketState voiceState;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.gray100)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    label: 'Hardware',
                    icon: Icons.developer_board_rounded,
                    selected: currentIndex == 0,
                    onTap: () => onChanged(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    label: 'Models',
                    icon: Icons.schema_rounded,
                    selected: currentIndex == 1,
                    onTap: () => onChanged(1),
                  ),
                ),
                Expanded(
                  child: _AiSlot(
                    onTap: onAiTap,
                    onHoldStart: onAiHoldStart,
                    onHoldEnd: onAiHoldEnd,
                    voiceState: voiceState,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    label: 'Logs',
                    icon: Icons.terminal_rounded,
                    selected: currentIndex == 2,
                    onTap: () => onChanged(2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    label: 'Data',
                    icon: Icons.input_rounded,
                    selected: currentIndex == 3,
                    onTap: () => onChanged(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange600 : AppColors.gray400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 26,
              child: Icon(icon, size: 25, color: color),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSlot extends StatelessWidget {
  const _AiSlot({
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.voiceState,
  });

  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoiceSocketState voiceState;

  @override
  Widget build(BuildContext context) {
    final active = voiceState.active;
    final color = switch (voiceState.phase) {
      VoiceSocketPhase.recording => AppColors.red600,
      VoiceSocketPhase.waiting ||
      VoiceSocketPhase.responding =>
        const Color(0xFF2563EB),
      VoiceSocketPhase.connecting => AppColors.orange700,
      VoiceSocketPhase.error => AppColors.gray500,
      VoiceSocketPhase.idle => AppColors.orange600,
    };

    return SizedBox(
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -22,
            child: GestureDetector(
              onTap: onTap,
              onLongPressStart: (_) => onHoldStart(),
              onLongPressEnd: (_) => onHoldEnd(),
              onLongPressCancel: onHoldEnd,
              child: Material(
                color: color,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white, width: 4),
                ),
                elevation: active ? 7 : 4,
                shadowColor: Colors.black26,
                child: const SizedBox(
                  width: 60,
                  height: 60,
                  child: Icon(
                    Icons.bolt,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
