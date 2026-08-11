import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_notes/domain/ai/conversation_reference.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_controller.dart';
import 'package:nx_notes/features/live_conversation/openai_api_key.dart';

typedef NoteLiveConversationControllerFactory =
    NoteLiveConversationController Function();

final noteLiveConversationControllerFactoryProvider =
    Provider<NoteLiveConversationControllerFactory>(
      (_) =>
          () => NoteLiveConversationController(
            session: LiveAgentSession(transport: OpenAiRealtimeTransport()),
          ),
    );

final noteLiveConversationCredentialProvider =
    Provider<LiveAgentCredentialProvider>(
      (_) => const StaticLiveAgentCredentialProvider(openAiApiKey),
    );

final noteLiveConversationCoordinatorProvider =
    Provider.autoDispose<NoteLiveConversationCoordinator>((ref) {
      final coordinator = NoteLiveConversationCoordinator(
        createController: ref.watch(
          noteLiveConversationControllerFactoryProvider,
        ),
        credentialProvider: ref.watch(noteLiveConversationCredentialProvider),
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

class NoteLiveConversationCoordinator extends ChangeNotifier {
  NoteLiveConversationCoordinator({
    required NoteLiveConversationControllerFactory createController,
    required LiveAgentCredentialProvider credentialProvider,
  }) : _createController = createController,
       _credentialProvider = credentialProvider;

  final NoteLiveConversationControllerFactory _createController;
  final LiveAgentCredentialProvider _credentialProvider;

  NoteLiveConversationController? _controller;
  NxDocument? _sourceDocument;
  List<ConversationReference> _references = const <ConversationReference>[];
  bool _stopping = false;
  bool _ended = false;
  bool _disposed = false;

  NoteLiveConversationController? get controller => _controller;
  NxDocument? get sourceDocument => _sourceDocument;
  List<ConversationReference> get references => _references;
  bool get hasConversation => _controller != null;
  bool get isActive => hasConversation && !_ended;
  bool get isStopping => _stopping;
  bool get hasRecap => hasConversation && _ended;

  Future<bool> start({
    required NxDocument document,
    List<ConversationReference> references = const <ConversationReference>[],
  }) async {
    if (hasConversation) return false;
    final controller = _createController();
    _controller = controller;
    _sourceDocument = document;
    _references = List<ConversationReference>.unmodifiable(references);
    _ended = false;
    controller.addListener(_relayControllerChange);
    notifyListeners();
    await controller.start(
      document: document,
      references: _references,
      credentialProvider: _credentialProvider,
    );
    return true;
  }

  Future<void> stop() async {
    final controller = _controller;
    if (controller == null || _ended || _stopping) return;
    _stopping = true;
    notifyListeners();
    try {
      await controller.end();
      _ended = true;
    } finally {
      _stopping = false;
      notifyListeners();
    }
  }

  void dismissRecap() {
    final controller = _controller;
    if (controller == null || !_ended) return;
    controller.removeListener(_relayControllerChange);
    controller.dispose();
    _controller = null;
    _sourceDocument = null;
    _references = const <ConversationReference>[];
    _ended = false;
    notifyListeners();
  }

  void _relayControllerChange() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final controller = _controller;
    controller?.removeListener(_relayControllerChange);
    controller?.dispose();
    super.dispose();
  }
}
