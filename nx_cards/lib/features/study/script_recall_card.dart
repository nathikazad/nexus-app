import 'package:flutter/material.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/script_drawing_canvas.dart';

class ScriptRecallCard extends StatefulWidget {
  const ScriptRecallCard({
    super.key,
    required this.prompt,
    required this.revealed,
    required this.onDrawingChanged,
  });

  final StudyPrompt prompt;
  final bool revealed;
  final ValueChanged<bool> onDrawingChanged;

  @override
  State<ScriptRecallCard> createState() => _ScriptRecallCardState();
}

class _ScriptRecallCardState extends State<ScriptRecallCard> {
  final ScriptDrawingController _drawingController = ScriptDrawingController();

  LanguageCardContent get _content =>
      widget.prompt.card.content as LanguageCardContent;

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
      Text(
        widget.prompt.prompt,
        key: const ValueKey<String>('script-recall-sound'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 30,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
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
      if (widget.revealed) ...[
        const SizedBox(height: 8),
        Container(
          key: const ValueKey<String>('script-recall-answer'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: RecallColors.soft,
            border: Border.all(color: RecallColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text('CORRECT LETTER', style: monoLabel),
              const SizedBox(height: 6),
              Text(
                _content.originalScript,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 54,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
