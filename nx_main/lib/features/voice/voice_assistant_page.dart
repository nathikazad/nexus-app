import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/core/widgets/message_bubble.dart';
import 'package:nexus_voice_assistant/data/voice/voice_transcript_notifier.dart';
import 'package:nexus_voice_assistant/domain/voice/voice_transcript.dart';
import 'package:nexus_voice_assistant/features/voice/voice_assistant_view_model.dart';

class VoiceAssistantPage extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToHardwareTab;

  const VoiceAssistantPage({super.key, this.onSwitchToHardwareTab});

  @override
  ConsumerState<VoiceAssistantPage> createState() =>
      _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends ConsumerState<VoiceAssistantPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  bool _hasRefreshedOnMount = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasRefreshedOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(voiceAssistantViewModelProvider.notifier).refreshTranscript();
          _hasRefreshedOnMount = true;
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendTextMessage() async {
    final raw = _textController.text;
    _textController.clear();
    try {
      await ref
          .read(voiceAssistantViewModelProvider.notifier)
          .sendTrimmedText(raw);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to send message: $e');
      }
    }
  }

  void _clearConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text(
            'This will only clear the local view. Messages remain in the database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(voiceAssistantViewModelProvider.notifier).refreshTranscript();
              Navigator.of(context).pop();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(voiceAssistantViewModelProvider);
    final t = vm.transcript;

    ref.listen(voiceAssistantViewModelProvider, (prev, next) {
      if (next.transcript.transcript != null &&
          next.transcript.transcript!.sortedMessages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh transcript',
            onPressed: () => ref
                .read(voiceAssistantViewModelProvider.notifier)
                .refreshTranscript(),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear conversation',
            onPressed: _clearConversation,
          ),
        ],
      ),
      body: _buildBody(t),
    );
  }

  Widget _buildBody(VoiceTranscriptState vm) {
    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (vm.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading transcript',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              vm.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(voiceAssistantViewModelProvider.notifier)
                  .refreshTranscript(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final transcript = vm.transcript;
    if (transcript == null) {
      return const Center(
        child: Text('No transcript found. Please check your user ID.'),
      );
    }

    final messages = transcript.sortedMessages;

    return Column(
      children: [
        Expanded(
          child: _MessagesList(
            messages: messages,
            scrollController: _scrollController,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendTextMessage,
                tooltip: 'Send message',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessagesList extends StatelessWidget {
  final List<VoiceTranscriptMessage> messages;
  final ScrollController scrollController;

  const _MessagesList({
    required this.messages,
    required this.scrollController,
  });

  List<ChatMessage> _convertToChatMessages() {
    return messages
        .map((msg) => ChatMessage(
              text: msg.message,
              isFromUser: msg.isFromUser,
              timestamp: DateTime.tryParse(msg.timestamp) ?? DateTime.now(),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final chatMessages = _convertToChatMessages();

    if (chatMessages.isEmpty) {
      return const Center(
        child: Text('No messages yet. Start a conversation!'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatMessages.length,
      itemBuilder: (context, index) {
        final message = chatMessages[index];
        return MessageBubble(
          message: message,
        );
      },
    );
  }
}
