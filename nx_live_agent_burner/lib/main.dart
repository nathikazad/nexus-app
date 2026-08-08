import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

import 'burner_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeLiveAgentPlatform();
  runApp(const BurnerApp());
}

class BurnerApp extends StatelessWidget {
  const BurnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff5de4c7);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Agent Burner',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff101314),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: const BurnerScreen(),
    );
  }
}

class BurnerScreen extends StatefulWidget {
  const BurnerScreen({super.key});

  @override
  State<BurnerScreen> createState() => _BurnerScreenState();
}

class _BurnerScreenState extends State<BurnerScreen>
    with WidgetsBindingObserver {
  static const _definedApiKey = String.fromEnvironment('OPENAI_API_KEY');

  late final BurnerController controller;
  late final TextEditingController keyController;
  final transcriptController = ScrollController();
  AppLifecycleState lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = BurnerController();
    controller.addListener(_scrollTranscript);
    keyController = TextEditingController(text: _definedApiKey);
    if (_definedApiKey.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    lifecycle = state;
    controller.noteLifecycle(state.name);
  }

  void _scrollTranscript() {
    if (!transcriptController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (transcriptController.hasClients) {
        transcriptController.animateTo(
          transcriptController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _start() async {
    final key = keyController.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an API key for this burner run.')),
      );
      return;
    }
    keyController.clear();
    await controller.start(key);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_scrollTranscript);
    controller.dispose();
    keyController.dispose();
    transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final running = controller.isRunning;
        return Scaffold(
          appBar: AppBar(
            title: const Text('LIVE AGENT BURNER'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: _StatusPill(
                    label: controller.phase.name.toUpperCase(),
                    active: running,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const Text(
                  'Disposable test for WebRTC audio, background conversation, '
                  'barge-in, and function tools.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 18),
                if (!running) ...[
                  TextField(
                    controller: keyController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'OpenAI API key — held in memory only',
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: controller.phase == LiveAgentPhase.connecting
                        ? null
                        : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start voice session'),
                  ),
                ] else ...[
                  _TestCard(
                    title: 'Background test',
                    icon: Icons.phone_locked,
                    child: const Text(
                      'Lock the phone or switch apps, then say “give me a random '
                      'number” or “what is the weather in Kochi, India?” Return '
                      'here to '
                      'inspect the transcript and tool log.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TestCard(
                    title: 'Interruption test',
                    icon: Icons.record_voice_over,
                    child: Text(
                      'Ask for a long explanation, then speak over it. Barge-ins '
                      'detected: ${controller.bargeInCount}. The stop button below '
                      'also cancels the current response explicitly.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.cloud_outlined),
                        label: const Text('Weather in Kochi'),
                        onPressed: controller.askWeather,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.casino_outlined),
                        label: const Text('Random number'),
                        onPressed: controller.askRandom,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.article_outlined),
                        label: const Text('Long answer'),
                        onPressed: controller.askLongAnswer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.phase == LiveAgentPhase.speaking
                              ? controller.interrupt
                              : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop AI speech'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: controller.muted ? 'Unmute' : 'Mute',
                        onPressed: controller.toggleMuted,
                        icon: Icon(
                          controller.muted ? Icons.mic_off : Icons.mic,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'End session',
                        onPressed: controller.stop,
                        icon: const Icon(Icons.call_end),
                      ),
                    ],
                  ),
                ],
                if (controller.error case final error?) ...[
                  const SizedBox(height: 16),
                  Text(error, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 22),
                _SectionHeader(
                  title: 'TRANSCRIPT',
                  detail: 'app ${lifecycle.name}',
                ),
                const SizedBox(height: 8),
                Container(
                  height: 210,
                  padding: const EdgeInsets.all(14),
                  decoration: _panelDecoration,
                  child: SingleChildScrollView(
                    controller: transcriptController,
                    child: SelectableText(
                      controller.transcript.isEmpty
                          ? 'Transcript will appear here.'
                          : controller.transcript,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionHeader(title: 'TOOL & LIFECYCLE LOG'),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(minHeight: 100),
                  padding: const EdgeInsets.all(14),
                  decoration: _panelDecoration,
                  child: SelectableText(
                    controller.log.isEmpty
                        ? 'No events yet.'
                        : controller.log.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const _panelDecoration = BoxDecoration(
  color: Color(0xff181d1f),
  borderRadius: BorderRadius.all(Radius.circular(14)),
  border: Border.fromBorderSide(BorderSide(color: Color(0xff30383a))),
);

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active ? const Color(0xff193f38) : const Color(0xff2a2e30),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: active ? const Color(0xff5de4c7) : Colors.white60,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _panelDecoration,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white70, height: 1.4),
                child: child,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.white60,
        ),
      ),
      const Spacer(),
      if (detail != null)
        Text(detail!, style: const TextStyle(color: Colors.white38)),
    ],
  );
}
