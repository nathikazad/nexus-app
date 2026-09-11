import 'package:flutter/material.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/study/language/drawing/script_drawing_canvas.dart';

class WritingRecallCard extends StatefulWidget {
  const WritingRecallCard({
    super.key,
    required this.prompt,
    required this.revealed,
    this.audioRepository,
  });

  final StudyPrompt prompt;
  final bool revealed;
  final CardAudioRepository? audioRepository;

  @override
  State<WritingRecallCard> createState() => _WritingRecallCardState();
}

class _WritingRecallCardState extends State<WritingRecallCard> {
  final ScriptDrawingController _drawingController = ScriptDrawingController();

  LanguageCardContent get _content =>
      widget.prompt.card.content as LanguageCardContent;

  String get _answer => widget.prompt.cue == StudyCue.fromLanguage
      ? _content.originalScript
      : _content.english;

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
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child:
                !widget.revealed && widget.prompt.cue == StudyCue.fromLanguage
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _content.english.replaceAll(RegExp(r'\s+'), ' ').trim(),
                      key: const ValueKey('writing-recall-prompt'),
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 38,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                      ),
                    ),
                  )
                : Text(
                    widget.revealed ? _answer : widget.prompt.prompt,
                    key: ValueKey<String>(
                      widget.revealed
                          ? 'writing-recall-answer'
                          : 'writing-recall-prompt',
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
          if (widget.revealed)
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
      if (!widget.revealed && widget.prompt.showEnglishAndTransliteration) ...[
        const SizedBox(height: 8),
        Text(
          _content.transliteration,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24),
        ),
      ],
      if (widget.revealed) ...[
        const SizedBox(height: 8),
        Text(_content.transliteration, textAlign: TextAlign.center),
        Text(
          widget.prompt.cue == StudyCue.fromLanguage
              ? _content.english
              : _content.originalScript,
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: 8),
      Text(
        widget.revealed
            ? 'Compare your drawing with the answer'
            : 'Write your answer',
        style: const TextStyle(color: RecallColors.faint, fontSize: 12),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 230,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ScriptDrawingCanvas(
              controller: _drawingController,
              semanticsLabel: 'Write the answer for ${widget.prompt.prompt}',
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Erase',
                onPressed: _drawingController.hasStrokes
                    ? _drawingController.clear
                    : null,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
