import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_voice/nx_voice.dart';

/// Page selection is reference data, not a replacement for server authorization.
class PeopleAssistantContext {
  const PeopleAssistantContext({
    required this.kind,
    required this.id,
    required this.name,
  });
  final String kind;
  final int id;
  final String name;
  String get reference => jsonEncode({
    'app': 'nx_people',
    'selected_record': {'model_type': kind, 'id': id, 'name': name},
  });
}

void openPeopleAssistant(
  BuildContext context, {
  PeopleAssistantContext? selection,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PeopleAssistantPage(selection: selection),
    ),
  );
}

class PeopleAssistantButton extends StatefulWidget {
  const PeopleAssistantButton({super.key, this.selection});
  final PeopleAssistantContext? selection;
  @override
  State<PeopleAssistantButton> createState() => _PeopleAssistantButtonState();
}

class _PeopleAssistantButtonState extends State<PeopleAssistantButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  @override
  void initState() {
    super.initState();
    _hold.value = 0;
  }

  OverlayEntry? _hint;
  void _clearHint() {
    _hold.stop();
    _hint?.remove();
    _hint?.dispose();
    _hint = null;
  }

  void _holdDown() {
    _clearHint();
    _hint = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.paddingOf(context).top + 64,
        left: 16,
        right: 16,
        child: IgnorePointer(
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: AnimatedBuilder(
                animation: _hold,
                builder: (_, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Keep holding to record…"),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: _hold.value),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_hint!);
    _hold.forward(from: 0);
  }

  OverlayEntry? _overlay;
  GlobalKey<_PeopleAssistantPageState>? _page;
  bool _held = false;
  void _close() {
    _held = false;
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
    _page = null;
  }

  void _start() {
    _clearHint();
    _close();
    _held = true;
    final key = GlobalKey<_PeopleAssistantPageState>();
    _page = key;
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 12,
        right: 12,
        top: MediaQuery.paddingOf(context).top + 64,
        height: MediaQuery.sizeOf(context).height * .42,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: PeopleAssistantPage(
            key: key,
            selection: widget.selection,
            onClose: _close,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_held) key.currentState?._startVoice();
    });
  }

  void _stop() {
    _clearHint();
    _held = false;
    _page?.currentState?._stopVoice();
  }

  @override
  void dispose() {
    _clearHint();
    _hold.dispose();
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    gestures: {
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(),
            (instance) => instance
              ..onTap = () {
                _close();
                openPeopleAssistant(context, selection: widget.selection);
              },
          ),
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: const Duration(seconds: 2),
            ),
            (instance) => instance
              ..onLongPressDown = ((_) => _holdDown())
              ..onLongPress = _start
              ..onLongPressEnd = ((_) => _stop())
              ..onLongPressCancel = _stop,
          ),
    },
    child: IgnorePointer(
      child: FloatingActionButton(
        heroTag: null,
        tooltip: widget.selection == null
            ? 'Ask AI'
            : 'Ask AI about ${widget.selection!.name}',
        backgroundColor: const Color(0xffea580c),
        foregroundColor: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 3),
        ),
        onPressed: () {
          _close();
          openPeopleAssistant(context, selection: widget.selection);
        },
        child: const Icon(Icons.bolt, size: 28),
      ),
    ),
  );
}

final peopleMicrophoneFactoryProvider =
    Provider<NxMicrophoneOpusStreamer Function()>(
      (ref) =>
          () => NxMicrophoneOpusStreamer(),
    );

final peopleAiSessionFactoryProvider = Provider<DocumentAiSession Function()>(
  (ref) =>
      () => DocumentAiSession(),
);

class PeopleAssistantPage extends ConsumerStatefulWidget {
  const PeopleAssistantPage({super.key, this.selection, this.onClose});
  final VoidCallback? onClose;
  final PeopleAssistantContext? selection;
  @override
  ConsumerState<PeopleAssistantPage> createState() =>
      _PeopleAssistantPageState();
}

class _PeopleAssistantPageState extends ConsumerState<PeopleAssistantPage>
    with WidgetsBindingObserver {
  late final DocumentAiSession _session;
  NxMicrophoneOpusStreamer? _mic;
  bool _voiceWanted = false;
  bool _startingVoice = false;
  bool _recording = false;
  String _voiceStage = 'Connecting…';
  String? _imageUrl;
  String? _imageName;
  int? _voiceIndex;
  String get _reference => jsonEncode({
    ...jsonDecode(
          widget.selection?.reference ??
              '{"app":"nx_people","selected_record":null}',
        )
        as Map<String, dynamic>,
    if (_imageUrl != null) 'image_attachment': _imageUrl,
  });

  Future<void> _connect() async {
    final user = await ref.read(authProvider.future);
    if (!mounted || _closed) return;
    final url = ref.read(sockWsUrlProvider);
    if (user == null || user.domainId == null || url == null) {
      throw StateError('Sign in and select a domain');
    }
    await _session.connect(
      DocumentAiSessionConfig(
        socketUrl: url,
        userId: user.userId,
        domainId: user.requiredDomainId,
        clientId: 'nx_people',
        authHeaders: (refresh) =>
            nexusAuthHeaders(user.preset, user.userId, forceRefresh: refresh),
      ),
    );
  }

  Future<void> _startVoice() async {
    if (_busy || _closed) return;
    _voiceWanted = true;
    _startingVoice = true;
    setState(() {
      _busy = true;
      _error = null;
      _replyIndex = null;
    });
    final mic = _mic ??= ref.read(peopleMicrophoneFactoryProvider)();
    try {
      setState(() {
        _voiceStage = 'Requesting microphone…';
      });
      if (!await mic.ensurePermission()) {
        throw StateError(
          'Microphone permission denied. Enable Microphone for NX People in iPhone Settings.',
        );
      }
      if (!mounted || _closed || !_voiceWanted) return;
      setState(() {
        _voiceStage = 'Connecting to the assistant…';
      });
      await _connect();
      if (!mounted || _closed || !_voiceWanted) return;
      setState(() {
        _voiceStage = 'Starting microphone…';
      });
      _session.beginAudioTurn(context: _reference);
      final started = await mic.start(
        onOpusPacket: (packet) {
          if (!_closed && _voiceWanted) _session.sendAudioPacket(packet);
        },
        onError: (_) {
          _voiceWanted = false;
          unawaited(_stopVoice());
        },
      );
      if (!mounted || _closed || !_voiceWanted) {
        await mic.stop(flushRemainder: false);
        if (!_closed) _session.endAudioTurn();
        return;
      }
      if (!started) {
        _session.endAudioTurn();
        throw StateError('Microphone unavailable');
      }
      setState(() {
        _recording = true;
      });
    } catch (error) {
      debugPrint(
        '[people assistant] voice failed during $_voiceStage: ${error.runtimeType}',
      );
      _voiceWanted = false;
      _finish(
        error: _voiceStage == 'Connecting to the assistant…'
            ? 'Could not connect to the assistant. Please retry.'
            : _voiceStage == 'Requesting microphone…'
            ? 'Microphone permission is required. Enable Microphone for NX People in iPhone Settings.'
            : 'Could not start the microphone. Please retry.',
      );
    } finally {
      _startingVoice = false;
      if (mounted && !_closed && !_voiceWanted) {
        setState(() {
          _busy = false;
        });
      }
      if (_closed) await mic.dispose();
    }
  }

  Future<void> _stopVoice() async {
    _voiceWanted = false;
    if (_startingVoice || !_recording) return;
    setState(() {
      _recording = false;
    });
    try {
      final tail = await _mic!.stop();
      if (!mounted || _closed) return;
      for (final packet in tail) {
        _session.sendAudioPacket(packet);
      }
      _voiceIndex = _messages.length;
      setState(() {
        _messages.add((user: true, text: 'Voice message'));
      });
      _session.endAudioTurn();
      _armTimeout();
    } catch (_) {
      _finish(error: 'Could not send the recording.');
    }
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(
      const Duration(seconds: 90),
      () => _finish(
        error:
            'The reply is taking longer than expected. Check the profile before retrying.',
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_busy || _closed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final assets = ref.read(peopleAssetsProvider);
      if (assets == null) throw StateError('Sign in first');
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (!mounted || _closed || picked == null) return;
      final file = picked.files.single;
      if (file.bytes == null || file.size > 4 * 1024 * 1024) {
        throw StateError('Choose an image under 4 MB');
      }
      final local = await assets.stage(file.bytes!, file.name);
      final url = await assets.resolve(local) as String;
      if (mounted && !_closed) {
        setState(() {
          _imageUrl = url;
          _imageName = file.name;
        });
      }
    } catch (_) {
      _finish(
        error: 'Could not attach image. Choose a JPG, PNG or WebP under 4 MB.',
      );
    } finally {
      if (mounted && !_closed) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <({bool user, String text})>[];
  Timer? _timeout;
  bool _busy = false;
  String? _error;
  int? _replyIndex;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = ref.read(peopleAiSessionFactoryProvider)();
    _session.onTextChunk = (packet) => _receive(packet.text);
    _session.onTextEof = (_) => _finish();
    _session.onError = (error) => _finish(
      error:
          'Could not complete the request. Check your connection before retrying.',
    );
  }

  void _finish({String? error}) {
    if (!mounted || _closed) return;
    _timeout?.cancel();
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  void _receive(String raw) {
    if (!mounted || _closed) return;
    var text = raw;
    var append = true;
    try {
      final value = jsonDecode(raw);
      if (value is! Map ||
          (value['role'] != 'assistant' && value['role'] != 'user') ||
          value['text'] is! String) {
        return;
      }
      if (value['type'] != 'transcript' &&
          value['type'] != 'transcript-delta') {
        return;
      }
      if (value['role'] == 'user') {
        if (_voiceIndex != null) {
          setState(() {
            _messages[_voiceIndex!] = (
              user: true,
              text: value['text'] as String,
            );
          });
        }
        return;
      }
      text = value['text'] as String;
      append = value['type'] == 'transcript-delta';
    } on FormatException {
      /* Legacy plain-text response. */
    }
    if (text.isEmpty) return;
    setState(() {
      if (_replyIndex == null) {
        _replyIndex = _messages.length;
        _messages.add((user: false, text: text));
      } else {
        final old = _messages[_replyIndex!];
        _messages[_replyIndex!] = (
          user: false,
          text: append ? old.text + text : text,
        );
      }
    });
    _scrollDown();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send() async {
    final text = _input.text.trim().isEmpty && _imageUrl != null
        ? 'Please inspect this image.'
        : _input.text.trim();
    if (text.isEmpty || _busy || _closed) return;
    final user = ref.read(authProvider).value;
    final url = ref.read(sockWsUrlProvider);
    if (user == null || user.domainId == null || url == null) {
      _finish(error: 'Sign in and select a domain to use the assistant.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _replyIndex = null;
    });
    try {
      await _session.connect(
        DocumentAiSessionConfig(
          socketUrl: url,
          userId: user.userId,
          domainId: user.requiredDomainId,
          clientId: 'nx_people',
          authHeaders: (refresh) =>
              nexusAuthHeaders(user.preset, user.userId, forceRefresh: refresh),
        ),
      );
      if (!mounted || _closed) return;
      _session.sendTextTurn(text, context: _reference);
      setState(() {
        _messages.add((user: true, text: text));
        _input.clear();
        _imageUrl = null;
        _imageName = null;
      });
      _scrollDown();
      _timeout = Timer(
        const Duration(seconds: 90),
        () => _finish(
          error:
              'The reply is taking longer than expected. Check the profile before sending the action again.',
        ),
      );
    } catch (_) {
      _finish(
        error:
            'Could not connect to the assistant. Your message is still here to retry.',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_stopVoice());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closed = true;
    _voiceWanted = false;
    if (!_startingVoice) unawaited(_mic?.dispose());
    _timeout?.cancel();
    unawaited(_session.disconnect());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      final old = previous?.value;
      final user = next.value;
      if (old != null &&
          (old.userId != user?.userId ||
              old.domainId != user?.domainId ||
              old.preset != user?.preset)) {
        _closed = true;
        _voiceWanted = false;
        if (!_startingVoice) unawaited(_mic?.dispose());
        _timeout?.cancel();
        unawaited(_session.disconnect());
        setState(() {
          _messages.clear();
          _busy = false;
          _error =
              'Account or domain changed. Close this chat and open it again.';
        });
      }
    });
    if (widget.onClose != null) {
      return SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.selection?.name ?? 'People assistant'),
                  ),
                  IconButton(
                    tooltip: 'Close assistant',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_recording)
                const _RecordingAnimation()
              else if (_startingVoice || _busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(_startingVoice ? _voiceStage : 'Thinking…'),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final message in _messages)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SelectableText(
                            message.text,
                            style: TextStyle(
                              color: message.user
                                  ? Theme.of(context).hintColor
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!_busy && _messages.isEmpty && _error == null)
                const Text('Hold the AI button to record.'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selection?.name ?? 'People assistant'),
        automaticallyImplyLeading: widget.onClose == null,
        actions: [
          if (widget.onClose != null)
            IconButton(
              tooltip: 'Close assistant',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.selection != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'About this ${widget.selection!.kind == 'Meet' ? 'meeting' : 'person'}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Ask a question, add contact details, or share a note.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) {
                        final message = _messages[index];
                        return Align(
                          alignment: message.user
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: message.user
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SelectableText(message.text),
                          ),
                        );
                      },
                    ),
            ),
            if (_recording || _startingVoice)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _recording
                      ? 'Recording… release or tap Stop to send'
                      : 'Starting microphone…',
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_imageName != null)
              ListTile(
                leading: const Icon(Icons.image),
                title: Text(_imageName!),
                trailing: IconButton(
                  tooltip: 'Remove image',
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _imageUrl = null;
                          _imageName = null;
                        }),
                  icon: const Icon(Icons.close),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach image',
                    onPressed: _busy || _closed ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  IconButton(
                    tooltip: _recording || _startingVoice
                        ? 'Stop recording'
                        : 'Record voice',
                    onPressed:
                        _closed || (_busy && !_recording && !_startingVoice)
                        ? null
                        : () => _recording || _startingVoice
                              ? _stopVoice()
                              : _startVoice(),
                    icon: Icon(
                      _recording || _startingVoice
                          ? Icons.stop_circle
                          : Icons.mic,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_busy && !_closed,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Message the assistant',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send message',
                    onPressed: _busy || _closed ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A recording indicator, not an audio-level meter.
class _RecordingAnimation extends StatefulWidget {
  const _RecordingAnimation();
  @override
  State<_RecordingAnimation> createState() => _RecordingAnimationState();
}

class _RecordingAnimationState extends State<_RecordingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Recording. Release to send.',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: .35, end: 1).animate(_pulse),
            child: const Icon(Icons.mic, color: Colors.red, size: 32),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Recording…\nRelease to send')),
        ],
      ),
    ),
  );
}
