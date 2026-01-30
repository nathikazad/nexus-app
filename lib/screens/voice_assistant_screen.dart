import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data_providers/transcript_provider.dart';
import 'package:nexus_voice_assistant/models/transcript_message.dart';
import 'package:nexus_voice_assistant/widgets/message_bubble.dart';
import 'package:nexus_voice_assistant/background_service.dart';

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
  bool _hasRefreshedOnMount = false;
  
  Transcript? _transcript;
  bool _isLoading = true;
  Object? _error;
  StreamSubscription<TranscriptMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadTranscript();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh transcript when screen becomes visible (only once per mount)
    if (!_hasRefreshedOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('voice assistant screen: Refreshing transcript');
          _loadTranscript();
          _hasRefreshedOnMount = true;
        }
      });
    }
  }

  Future<void> _loadTranscript() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final transcript = await TranscriptService.getTranscript();
      if (!mounted) return;
      
      setState(() {
        _transcript = transcript;
        _isLoading = false;
        if (transcript != null && _currentTranscriptId != transcript.id) {
          _currentTranscriptId = transcript.id;
          _startMessageSubscription();
        }
      });
      
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  void _startMessageSubscription() {
    // Cancel existing subscription
    _messageSubscription?.cancel();
    
    if (_currentTranscriptId == null) return;
    
    _messageSubscription = TranscriptService.streamMessages(_currentTranscriptId!).listen(
      (message) {
        if (mounted && _transcript != null) {
          // Add the new message to the existing transcript instead of refetching
          setState(() {
            _transcript = _transcript!.copyWithMessage(message);
          });
          _scrollToBottom();
        }
      },
      onError: (error) {
        debugPrint('Error in message subscription: $error');
      },
    );
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

    // Clear text field immediately
    _textController.clear();

    try {
      // Send text to socket server
      final bgService = ref.read(bleBackgroundServiceProvider);
      bgService.sendTextToSocket(text);
      bgService.sendEofToSocket(); // Signal end of text input
      
      // Also save to database
      // await TranscriptService.addMessage(
      //   transcriptId: _currentTranscriptId!,
      //   sender: 'Human',
      //   message: text,
      // );
      
      // Don't reload transcript - the subscription will handle the new message
      // The message will appear via the subscription stream
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to send message: $e');
      }
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
              _loadTranscript();
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
    _messageSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh transcript',
            onPressed: _loadTranscript,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear conversation',
            onPressed: _clearConversation,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_error != null) {
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
              _error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTranscript,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_transcript == null) {
      return const Center(
        child: Text('No transcript found. Please check your user ID.'),
      );
    }

    final messages = _transcript!.sortedMessages;
    
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
