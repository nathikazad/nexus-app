import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_voice/nx_voice.dart';

Future<void> showExpenseAssistant(BuildContext context) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Tell AI',
      barrierColor: const Color(0x990B1716),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const ExpenseAssistantPage(),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );

final expenseVoiceSessionProvider = Provider(
  (ref) =>
      () => DocumentAiSession(),
);
final expenseMicrophoneProvider = Provider(
  (ref) =>
      () => NxMicrophoneOpusStreamer(),
);

enum ExpenseVoicePhase { connecting, listening, sending, done, error }

class ExpenseAssistantPage extends ConsumerStatefulWidget {
  const ExpenseAssistantPage({super.key});
  @override
  ConsumerState<ExpenseAssistantPage> createState() =>
      _ExpenseAssistantPageState();
}

class _ExpenseAssistantPageState extends ConsumerState<ExpenseAssistantPage> {
  late final _session = ref.read(expenseVoiceSessionProvider)();
  late final _mic = ref.read(expenseMicrophoneProvider)();
  ExpenseVoicePhase _phase = ExpenseVoicePhase.connecting;
  String _transcript = '', _reply = '';
  String? _error;
  Timer? _timeout, _dismissTimer;

  @override
  void initState() {
    super.initState();
    _session.onTextChunk = (packet) => _receive(packet.text);
    _session.onTextEof = (_) {
      if (!mounted || _phase != ExpenseVoicePhase.sending) return;
      _timeout?.cancel();
      if (_reply.trim().isEmpty) {
        _fail('No confirmation received. Check your logs before trying again.');
        return;
      }
      setState(() => _phase = ExpenseVoicePhase.done);
      _dismissTimer = Timer(const Duration(seconds: 5), _close);
    };
    _session.onError = (_) =>
        _fail('Connection interrupted. Please close and try again.');
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _receive(String raw) {
    if (!mounted || _phase == ExpenseVoicePhase.error) return;
    var text = raw, role = 'assistant', append = true;
    try {
      final event = jsonDecode(raw);
      if (event is! Map ||
          event['text'] is! String ||
          !['transcript', 'transcript-delta'].contains(event['type']) ||
          !['user', 'assistant'].contains(event['role'])) {
        return;
      }
      text = event['text'] as String;
      role = event['role'] as String;
      append = event['type'] == 'transcript-delta';
      // Ephemeral agent status is not the agent's saved-note confirmation.
      if (event['ephemeral'] == true) return;
    } on FormatException {
      // Older socket agents send plain text chunks.
    }
    setState(() {
      if (role == 'user') {
        _transcript = append ? _transcript + text : text;
      } else {
        _reply = append ? _reply + text : text;
      }
    });
  }

  Future<void> _start() async {
    if (!mounted) return;
    try {
      final user = ref.read(authProvider).value;
      final url = ref.read(sockWsUrlProvider);
      if (user?.domainId == null || url == null) {
        _fail('Select a domain before recording.');
        return;
      }
      if (!await _mic.ensurePermission()) {
        _fail('Allow microphone access in Settings to tell AI by voice.');
        return;
      }
      if (!mounted) return;
      await _session.connect(
        DocumentAiSessionConfig(
          socketUrl: url,
          userId: user!.userId,
          domainId: user.requiredDomainId,
          clientId: 'nx_expense',
          authHeaders: (refresh) =>
              nexusAuthHeaders(user.preset, user.userId, forceRefresh: refresh),
        ),
      );
      if (!mounted || _phase == ExpenseVoicePhase.error) return;
      _session.beginAudioTurn();
      final started = await _mic.start(
        onOpusPacket: _session.sendAudioPacket,
        onError: (_) =>
            _fail('Recording interrupted. Please close and try again.'),
      );
      if (!mounted || _phase == ExpenseVoicePhase.error) {
        await _mic.stop(flushRemainder: false);
        return;
      }
      if (!started) throw StateError('Microphone unavailable');
      setState(() => _phase = ExpenseVoicePhase.listening);
    } catch (_) {
      _fail(
        'Could not start recording. Check your connection and microphone access.',
      );
    }
  }

  Future<void> _stop() async {
    if (_phase != ExpenseVoicePhase.listening) return;
    setState(() => _phase = ExpenseVoicePhase.sending);
    try {
      final remaining = await _mic.stop();
      if (!mounted || _phase != ExpenseVoicePhase.sending) return;
      for (final packet in remaining) {
        _session.sendAudioPacket(packet);
      }
      _timeout = Timer(
        const Duration(seconds: 60),
        () => _fail(
          'No confirmation received. Check your logs before trying again.',
        ),
      );
      _session.endAudioTurn();
    } catch (_) {
      _fail('Could not send the recording. Please close and try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    _timeout?.cancel();
    _dismissTimer?.cancel();
    unawaited(_mic.stop(flushRemainder: false));
    setState(() {
      _phase = ExpenseVoicePhase.error;
      _error = message;
    });
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _dismissTimer?.cancel();
    _session.onTextChunk = null;
    _session.onTextEof = null;
    _session.onError = null;
    unawaited(_mic.dispose());
    unawaited(_session.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpenseCaptureView(
    domain: ref.watch(authProvider).value?.domainName ?? 'Selected domain',
    phase: _phase,
    transcript: _transcript,
    reply: _reply,
    error: _error,
    onStop: _stop,
    onClose: _close,
  );
}

class ExpenseCaptureView extends StatelessWidget {
  const ExpenseCaptureView({
    super.key,
    required this.domain,
    required this.phase,
    required this.onStop,
    required this.onClose,
    this.transcript = '',
    this.reply = '',
    this.error,
  });
  final String domain, transcript, reply;
  final String? error;
  final ExpenseVoicePhase phase;
  final VoidCallback onStop, onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: MediaQuery.platformBrightnessOf(context),
    );
    final theme = ThemeData(useMaterial3: true, colorScheme: scheme);
    final status = switch (phase) {
      ExpenseVoicePhase.connecting => 'Getting ready…',
      ExpenseVoicePhase.listening => 'Listening',
      ExpenseVoicePhase.sending => 'Sending to AI…',
      ExpenseVoicePhase.done => 'All done',
      ExpenseVoicePhase.error => 'Something went wrong',
    };
    return Theme(
      data: theme,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.sizeOf(context).height * .8,
              ),
              child: Material(
                color: scheme.surface,
                elevation: 12,
                borderRadius: BorderRadius.circular(32),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tell AI',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            tooltip: 'Close',
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(
                        domain,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (phase == ExpenseVoicePhase.connecting ||
                          phase == ExpenseVoicePhase.sending)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 18),
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          transcript.isNotEmpty
                              ? transcript
                              : 'Tell me what you spent.\nI’m listening…',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (reply.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              reply,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            error!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (phase == ExpenseVoicePhase.listening) ...[
                        Center(
                          child: IconButton.filled(
                            onPressed: onStop,
                            tooltip: 'Stop and send',
                            style: IconButton.styleFrom(
                              minimumSize: const Size.square(72),
                            ),
                            icon: const Icon(Icons.stop_rounded, size: 34),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Stop to send',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                      if (phase == ExpenseVoicePhase.done ||
                          phase == ExpenseVoicePhase.error)
                        FilledButton(
                          onPressed: onClose,
                          child: const Text('Done'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
