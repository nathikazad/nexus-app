import 'package:flutter/material.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/language_audio_controls.dart';
import 'package:nx_cards/features/study/script_drawing_canvas.dart';

class ScriptRecallCard extends StatefulWidget {
  const ScriptRecallCard({
    super.key,
    required this.prompt,
    required this.revealed,
    required this.onDrawingChanged,
    this.audioRepository,
  });

  final StudyPrompt prompt;
  final bool revealed;
  final ValueChanged<bool> onDrawingChanged;
  final CardAudioRepository? audioRepository;

  @override
  State<ScriptRecallCard> createState() => _ScriptRecallCardState();
}

class _ScriptRecallCardState extends State<ScriptRecallCard> {
  final ScriptDrawingController _drawingController = ScriptDrawingController();

  LanguageCardContent get _content =>
      widget.prompt.card.content as LanguageCardContent;

  String get _sound => _content.english.replaceFirst(
    RegExp(r'^letter\s+', caseSensitive: false),
    '',
  );

  String? get _audioUrl {
    final value = _content.audioUrl?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    _drawingController.addListener(_drawingChanged);
  }

  @override
  void dispose() {
    _drawingController
      ..removeListener(_drawingChanged)
      ..dispose();
    super.dispose();
  }

  void _drawingChanged() {
    if (!mounted) return;
    setState(() {});
    widget.onDrawingChanged(_drawingController.hasStrokes);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              widget.revealed ? _content.originalScript : _sound,
              key: ValueKey<String>(
                widget.revealed
                    ? 'script-recall-answer'
                    : 'script-recall-sound',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 38,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
              ),
            ),
          ),
          if (_audioUrl case final audioUrl?
              when widget.audioRepository != null) ...[
            const SizedBox(width: 8),
            PronunciationButton(
              audioUrl: audioUrl,
              repository: widget.audioRepository!,
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Text(
        widget.revealed
            ? 'Compare your drawing with the answer'
            : 'Draw the Malayalam letter',
        style: const TextStyle(color: RecallColors.faint, fontSize: 12),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 230,
        child: ScriptDrawingCanvas(
          controller: _drawingController,
          semanticsLabel:
              'Draw the Malayalam letter for ${widget.prompt.prompt}',
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _drawingController.hasStrokes
              ? _drawingController.clear
              : null,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Erase'),
        ),
      ),
    ],
  );
}
