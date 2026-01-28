import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data_providers/transcript_provider.dart';
import 'package:nexus_voice_assistant/models/transcript_message.dart';
import 'package:nexus_voice_assistant/widgets/message_bubble.dart';
import 'package:nexus_voice_assistant/auth.dart';

class VoiceAssistantScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToHardwareTab;
  
  const VoiceAssistantScreen({super.key, this.onSwitchToHardwareTab});

  @override
  ConsumerState<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends ConsumerState<VoiceAssistantScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  int? _currentTranscriptId;

  @override
  void initState() {
    super.initState();
    // Invalidate transcript provider when entering screen to ensure fresh data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(currentTranscriptProvider);
    });
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
    final text = _textController.text.trim();
    if (text.isEmpty || _currentTranscriptId == null) {
      return;
    }

    final userIdStr = ref.read(userIdProvider);
    if (userIdStr == null) {
      _showErrorDialog('Not authenticated');
      return;
    }

    final userId = int.tryParse(userIdStr);
    if (userId == null) {
      _showErrorDialog('Invalid user ID');
      return;
    }

    // Clear text field immediately
    _textController.clear();

    try {
      await ref.read(sendMessageProvider(SendMessageParams(
        transcriptId: _currentTranscriptId!,
        sender: 'Human',
        message: text,
        userId: userId,
      )).future);
      
      _scrollToBottom();
    } catch (e) {
      _showErrorDialog('Failed to send message: $e');
    }
  }

  void _clearConversation() {
    // Note: This doesn't actually clear the transcript in the database
    // It just clears the local view. To fully clear, we'd need a mutation.
    // For now, we'll just show a message.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text('This will only clear the local view. Messages remain in the database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Invalidate to refresh
              ref.invalidate(currentTranscriptProvider);
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
    final transcriptAsync = ref.watch(currentTranscriptProvider);
    
    // Set up listener for transcript changes (must be in build method)
    ref.listen(currentTranscriptProvider, (previous, next) {
      next.whenData((transcript) {
        if (transcript != null && _currentTranscriptId != transcript.id) {
          setState(() {
            _currentTranscriptId = transcript.id;
          });
          _scrollToBottom();
        }
      });
    });
    
    // Set up subscription listener when transcript ID is available
    if (_currentTranscriptId != null) {
      ref.listen(
        transcriptMessagesStreamProvider(_currentTranscriptId!),
        (previous, next) {
          next.whenData((message) {
            // When a new message arrives, invalidate transcript to refresh
            if (mounted) {
              ref.invalidate(currentTranscriptProvider);
              _scrollToBottom();
            }
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh transcript',
            onPressed: () {
              ref.invalidate(currentTranscriptProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear conversation',
            onPressed: _clearConversation,
          ),
        ],
      ),
      body: transcriptAsync.when(
        data: (transcript) {
          if (transcript == null) {
            return const Center(
              child: Text('No transcript found. Please check your user ID.'),
            );
          }

          final messages = transcript.sortedMessages;
          
          return Column(
            children: [
              // Messages list
              Expanded(
                child: _MessagesList(
                  messages: messages,
                  scrollController: _scrollController,
                ),
              ),
              
              // Input area
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
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
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
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(currentTranscriptProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  final List<TranscriptMessage> messages;
  final ScrollController scrollController;

  const _MessagesList({
    required this.messages,
    required this.scrollController,
  });

  List<ChatMessage> _convertToChatMessages() {
    return messages.map((msg) {
      return ChatMessage(
        text: msg.message,
        isFromUser: msg.isFromUser,
        timestamp: DateTime.tryParse(msg.timestamp) ?? DateTime.now(),
      );
    }).toList();
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
