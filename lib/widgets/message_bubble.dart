import 'package:flutter/material.dart';

class ChatMessage {
  final String text;
  final bool isFromUser;
  final DateTime timestamp;
  final String? audioFilePath;
  
  ChatMessage({
    required this.text,
    required this.isFromUser,
    required this.timestamp,
    this.audioFilePath,
  });
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onPlayAudio;
  final bool isPlaying;
  
  const MessageBubble({
    super.key,
    required this.message,
    this.onPlayAudio,
    this.isPlaying = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isFromUser 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
        children: [
          if (!message.isFromUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isFromUser 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isFromUser
                      ? Theme.of(context).primaryColor
                      : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isFromUser ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                // Add playback button if audio file exists
                if (message.audioFilePath != null && message.isFromUser) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onPlayAudio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPlaying ? Icons.stop : Icons.play_arrow,
                            size: 16,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPlaying ? 'Stop' : 'Play',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
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
          if (message.isFromUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
