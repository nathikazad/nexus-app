import 'package:flutter/material.dart';

class InputArea extends StatelessWidget {
  final bool isConnected;
  final bool isRecording;
  final bool opusMode;
  final bool speakerEnabled;
  final TextEditingController textController;
  final VoidCallback onToggleRecording;
  final VoidCallback onToggleOpusMode;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onSendTextMessage;

  const InputArea({
    super.key,
    required this.isConnected,
    required this.isRecording,
    required this.opusMode,
    required this.speakerEnabled,
    required this.textController,
    required this.onToggleRecording,
    required this.onToggleOpusMode,
    required this.onToggleSpeaker,
    required this.onSendTextMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          // Voice recording button
          IconButton(
            onPressed: isConnected ? onToggleRecording : null,
            icon: Icon(isRecording ? Icons.stop : Icons.mic),
            style: IconButton.styleFrom(
              backgroundColor: isRecording ? Colors.red : Colors.grey[300],
              foregroundColor: isRecording ? Colors.white : Colors.black,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Opus mode toggle button
          IconButton(
            onPressed: isConnected ? onToggleOpusMode : null,
            icon: Icon(opusMode ? Icons.compress : Icons.compress_outlined),
            style: IconButton.styleFrom(
              backgroundColor: opusMode ? Theme.of(context).primaryColor : Colors.grey[300],
              foregroundColor: opusMode ? Colors.white : Colors.black,
            ),
            tooltip: opusMode ? 'Disable Opus compression' : 'Enable Opus compression',
          ),
          
          const SizedBox(width: 8),
          
          // Speaker toggle button
          IconButton(
            onPressed: isConnected ? onToggleSpeaker : null,
            icon: Icon(speakerEnabled ? Icons.volume_up : Icons.volume_off),
            style: IconButton.styleFrom(
              backgroundColor: speakerEnabled ? Theme.of(context).primaryColor : Colors.grey[300],
              foregroundColor: speakerEnabled ? Colors.white : Colors.black,
            ),
            tooltip: speakerEnabled ? 'Disable speaker' : 'Enable speaker',
          ),
          
          const SizedBox(width: 8),
          
          // Text input field
          Expanded(
            child: TextField(
              controller: textController,
              enabled: isConnected,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => onSendTextMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Send button
          IconButton(
            onPressed: isConnected ? onSendTextMessage : null,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: isConnected ? Theme.of(context).primaryColor : Colors.grey[300],
              foregroundColor: isConnected ? Colors.white : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
