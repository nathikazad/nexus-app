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
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => navBack(context)),
        title: const Text('Tell AI'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Daily Log · $domain',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Tell me what you spent, where, and what you bought. I’ll keep your words as a log.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _input,
                enabled: !_busy,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: r'Spent $30 at the grocery store on eggs, milk…',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy && !_recording ? null : _voice,
                    icon: Icon(_recording ? Icons.stop : Icons.mic_none),
                    label: Text(_recording ? 'Done speaking' : 'Speak'),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 20),
                Text(_recording ? 'Listening…' : 'Working…'),
              ],
              if (_reply.isNotEmpty) ...[
                const SizedBox(height: 20),
                SelectableText(_reply),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
