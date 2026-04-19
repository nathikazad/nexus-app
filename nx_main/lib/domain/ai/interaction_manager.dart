import 'dart:async';

import 'package:nexus_voice_assistant/domain/ai/interaction.dart';

/// Manages conversation interactions and provides streams for UI updates.
class InteractionManager {
  final List<Interaction> _interactions = [
    Interaction(userQuery: '', aiResponse: '', timestamp: DateTime.now())
  ];
  final StreamController<List<Interaction>> _interactionsController =
      StreamController<List<Interaction>>.broadcast();
  bool _responseDone = false;

  List<Interaction> get interactions => List.unmodifiable(_interactions);

  Stream<List<Interaction>> get interactionsStream =>
      _interactionsController.stream;

  void handleConversationEvent(Map<String, dynamic> data) {
    Interaction currentInteraction = _interactions.last;
    String type = data['type']!;

    if (type == 'transcript') {
      String speaker = data['speaker']!;
      String word = data['word']!;

      if (speaker == 'AI') {
        _responseDone = false;
        currentInteraction.addToAiResponse(word);
      } else {
        currentInteraction.addToUserQuery(word);
        if (_responseDone) {
          _interactions.add(Interaction(
            userQuery: '',
            aiResponse: '',
            timestamp: DateTime.now(),
            userAudioFilePath: currentInteraction.userAudioFilePath,
          ));
        }
      }
      _interactionsController.add(_interactions);
    } else if (type == 'response_done') {
      _responseDone = true;
      if (currentInteraction.userQuery.isNotEmpty) {
        _interactions.add(Interaction(
          userQuery: '',
          aiResponse: '',
          timestamp: DateTime.now(),
          userAudioFilePath: currentInteraction.userAudioFilePath,
        ));
      }
      _interactionsController.add(_interactions);
    }
  }

  void clearInteractions() {
    _interactions.clear();
    _interactions.add(
        Interaction(userQuery: '', aiResponse: '', timestamp: DateTime.now()));
    _responseDone = false;
    _interactionsController.add(_interactions);
  }

  Future<void> dispose() async {
    await _interactionsController.close();
  }
}
