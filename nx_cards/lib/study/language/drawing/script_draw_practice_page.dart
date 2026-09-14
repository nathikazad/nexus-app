import 'package:flutter/material.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/study/language/drawing/script_drawing_canvas.dart';

class ScriptDrawPracticePage extends StatefulWidget {
  const ScriptDrawPracticePage({
    super.key,
    required this.title,
    required this.cards,
    this.audioRepository,
  }) : assert(cards.length > 0);

  final String title;
  final List<StudyCard> cards;
  final CardAudioRepository? audioRepository;

  @override
  State<ScriptDrawPracticePage> createState() => _ScriptDrawPracticePageState();
}

class _ScriptDrawPracticePageState extends State<ScriptDrawPracticePage> {
  final ScriptDrawingController _drawingController = ScriptDrawingController();
  int _index = 0;
  bool _letterVisible = true;

  StudyCard get _card => widget.cards[_index];

  String get _letter {
    final content = _card.content;
    return content is LanguageCardContent ? content.originalScript : _card.back;
  }

  String get _sound {
    final content = _card.content;
    return content is LanguageCardContent
        ? '${content.transliteration} · ${content.english}'
        : _card.front;
  }

  String? get _audioUrl {
    final content = _card.content;
    if (content is! LanguageCardContent) return null;
    final value = content.audioUrl?.trim();
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
    if (mounted) setState(() {});
  }

  void _next() {
    if (_index == widget.cards.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    _drawingController.clear();
    setState(() => _index += 1);
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == widget.cards.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} · Draw'),
        leading: IconButton(
          tooltip: 'Quit drawing practice',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'CARD ${_index + 1} OF ${widget.cards.length}',
                        key: const ValueKey<String>('draw-practice-progress'),
                        style: monoLabel,
                      ),
                      const Spacer(),
                      Text(
                        'Practice only',
                        style: monoLabel.copyWith(color: RecallColors.faint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RecallPalette.of(context).soft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RecallPalette.of(context).line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Visibility(
                                    visible: _letterVisible,
                                    maintainSize: true,
                                    maintainAnimation: true,
                                    maintainState: true,
                                    child: SingleChildScrollView(
                                      child: Text(
                                        _letter,
                                        textAlign: TextAlign.center,
                                        key: const ValueKey<String>(
                                          'draw-practice-letter',
                                        ),
                                        style: TextStyle(
                                          fontSize: _letter.runes.length == 1
                                              ? 82
                                              : 32,
                                          height: 1,
                                          fontWeight: FontWeight.w500,
                                          color: RecallPalette.of(context).ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _sound,
                                  key: const ValueKey<String>(
                                    'draw-practice-sound',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: RecallColors.muted,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_audioUrl case final audioUrl?
                              when widget.audioRepository != null) ...[
                            const SizedBox(width: 12),
                            PronunciationButton(
                              key: ValueKey<String>(
                                'draw-practice-audio-${_card.id}',
                              ),
                              audioUrl: audioUrl,
                              repository: widget.audioRepository!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('PRACTICE', style: monoLabel),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ScriptDrawingCanvas(
                      controller: _drawingController,
                      semanticsLabel: _letterVisible
                          ? 'Drawing area for $_letter'
                          : 'Drawing area',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.outlined(
                        tooltip: 'Erase',
                        onPressed: _drawingController.hasStrokes
                            ? _drawingController.clear
                            : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        tooltip: _letterVisible
                            ? 'Hide character'
                            : 'Show character',
                        onPressed: () =>
                            setState(() => _letterVisible = !_letterVisible),
                        icon: Icon(
                          _letterVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        tooltip: last ? 'Finish' : 'Next',
                        onPressed: _next,
                        icon: Icon(
                          last
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
