import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_voice/nx_voice.dart';
import '../desktop/desktop_nav.dart';

class ExpenseAssistantPage extends ConsumerStatefulWidget {
  const ExpenseAssistantPage({super.key});

  @override
  ConsumerState<ExpenseAssistantPage> createState() =>
      _ExpenseAssistantPageState();
}

class _ExpenseAssistantPageState extends ConsumerState<ExpenseAssistantPage> {
  final _session = DocumentAiSession();
  final _input = TextEditingController();
  final _mic = NxMicrophoneOpusStreamer();
  bool _busy = false;
  bool _recording = false;
  String _reply = '';
  String? _error;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _session.onTextChunk = (packet) {
      if (mounted) setState(() => _reply += packet.text);
    };
    _session.onTextEof = (_) => _finish();
    _session.onError = (_) => _finish(
      error: 'Could not complete the request. Check your connection.',
    );
  }

  void _finish({String? error}) {
    _timeout?.cancel();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _connect() async {
    final user = ref.read(authProvider).value;
    final url = ref.read(sockWsUrlProvider);
    if (user?.domainId == null || url == null) {
      throw StateError('Select a domain first');
    }
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
  }

  void _waitForReply() {
    _timeout = Timer(
      const Duration(seconds: 60),
      () => _finish(
        error:
            'No confirmation received. Check whether the log was saved before retrying.',
      ),
    );
  }

  Future<void> _send() async {
    if (_busy || _input.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _reply = '';
      _error = null;
    });
    try {
      await _connect();
      if (!mounted) return;
      _session.sendTextTurn(_input.text);
      _waitForReply();
    } catch (_) {
      _finish(error: 'Could not connect. Your message is still here.');
    }
  }

  Future<void> _voice() async {
    if (_recording) {
      await _mic.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      _session.endAudioTurn();
      _waitForReply();
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _reply = '';
      _error = null;
    });
    try {
      if (!await _mic.ensurePermission()) {
        _finish(error: 'Allow microphone access to tell AI by voice.');
        return;
      }
      await _connect();
      if (!mounted) return;
      _session.beginAudioTurn();
      final started = await _mic.start(
        onOpusPacket: _session.sendAudioPacket,
        onError: (_) {
          unawaited(_mic.stop(flushRemainder: false));
          if (mounted) setState(() => _recording = false);
          _finish(error: 'Recording stopped. Please try again.');
        },
      );
      if (!mounted) return;
      if (!started) throw StateError('Microphone unavailable');
      setState(() => _recording = true);
    } catch (_) {
      _finish(error: 'Could not start recording. Please try again.');
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    unawaited(_mic.dispose());
    unawaited(_session.disconnect());
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domain =
        ref.watch(authProvider).value?.domainName ?? 'selected domain';
    return ExpenseCaptureView(
      domain: domain,
      controller: _input,
      busy: _busy,
      recording: _recording,
      reply: _reply,
      error: _error,
      onBack: () => navBack(context),
      onSend: _send,
      onVoice: _voice,
    );
  }
}

/// Owns a complete light/dark palette instead of mixing the app's fixed-light
/// input and button defaults with platform appearance.
class ExpenseCaptureView extends StatelessWidget {
  const ExpenseCaptureView({
    super.key,
    required this.domain,
    required this.controller,
    required this.onBack,
    required this.onSend,
    required this.onVoice,
    this.busy = false,
    this.recording = false,
    this.reply = '',
    this.error,
  });

  final String domain;
  final TextEditingController controller;
  final VoidCallback onBack, onSend, onVoice;
  final bool busy, recording;
  final String reply;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: dark ? const Color(0xFF142321) : Colors.white,
    );
    final background = dark ? const Color(0xFF0B1716) : const Color(0xFFF5F8F7);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );
    final text = theme.textTheme;
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          title: Text(
            'Tell AI',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_outline,
                            size: 16,
                            color: scheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Daily Log · $domain',
                              style: text.labelMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'What did you spend?',
                    style: text.headlineMedium?.copyWith(
                      fontSize: 30,
                      height: 1.15,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A place, an amount, a few details. Just tell it in your own words.',
                    style: text.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR NOTE',
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          enabled: !busy,
                          minLines: 5,
                          maxLines: 10,
                          cursorColor: scheme.primary,
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                            height: 1.6,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                '“Spent \$30 at the grocery store on eggs, milk and coffee.”',
                            hintStyle: text.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller,
                            builder: (context, value, _) => FilledButton.icon(
                              onPressed: busy || value.text.trim().isEmpty
                                  ? null
                                  : onSend,
                              icon: const Icon(Icons.arrow_upward, size: 18),
                              label: const Text('Send note'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(120, 48),
                                backgroundColor: scheme.primary,
                                foregroundColor: scheme.onPrimary,
                                disabledBackgroundColor:
                                    scheme.surfaceContainerHighest,
                                disabledForegroundColor:
                                    scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: busy && !recording ? null : onVoice,
                    icon: Icon(
                      recording
                          ? Icons.stop_circle_outlined
                          : Icons.mic_none_rounded,
                      size: 24,
                    ),
                    label: Text(recording ? 'Done speaking' : 'Speak instead'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.primary,
                      backgroundColor: recording
                          ? scheme.primaryContainer
                          : scheme.surface,
                      side: BorderSide(color: scheme.outlineVariant),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your words, saved as a Daily Log.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (busy) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (recording)
                          Icon(Icons.graphic_eq, color: scheme.primary)
                        else
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          recording ? 'Listening…' : 'Saving your note…',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (reply.isNotEmpty || error != null) ...[
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: error != null
                              ? scheme.errorContainer
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: error != null
                                ? scheme.error
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              error != null
                                  ? 'Couldn’t confirm the save'
                                  : 'NX Expense',
                              style: text.labelLarge?.copyWith(
                                color: error != null
                                    ? scheme.onErrorContainer
                                    : scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              error ?? reply,
                              style: text.bodyLarge?.copyWith(
                                color: error != null
                                    ? scheme.onErrorContainer
                                    : scheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
