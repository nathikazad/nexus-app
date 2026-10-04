import 'package:nx_cards/study/language/language_examples_page.dart';
import 'package:nx_cards/study/language/tablet_recall_context.dart';
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
    this.cues,
    this.initialIndex = 0,
  }) : assert(cards.length > 0);

  final String title;
  final int initialIndex;
  final List<StudyCard> cards;
  final CardAudioRepository? audioRepository;
  final List<StudyCue>? cues;

  @override
  State<ScriptDrawPracticePage> createState() => _ScriptDrawPracticePageState();
}

class _ScriptDrawPracticePageState extends State<ScriptDrawPracticePage> {
  final ScriptDrawingController _drawingController = ScriptDrawingController();
  int _index = 0;
  bool _letterVisible = true;

  StudyCard get _card => widget.cards[_index];

  StudyCue? get _cue => widget.cues?[_index];

  String get _letter {
    if (_cue != null) return StudyPrompt(card: _card, cue: _cue!).prompt;
    final content = _card.content;
    return content is LanguageCardContent ? content.originalScript : _card.back;
  }

  String get _sound {
    final content = _card.content;
    return content is LanguageCardContent
        ? '${_cue == null ? '' : '${content.originalScript} · '}${content.transliteration}\n${content.english}'
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
    _index = widget.initialIndex;
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

  Future<void> _next() async {
    if (_index == widget.cards.length - 1) {
      final repeat = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Practice complete'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Return'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Repeat'),
            ),
          ],
        ),
      );
      if (!mounted || repeat == null) return;
      if (!repeat) {
        Navigator.of(context).pop(true);
        return;
      }
      _drawingController.clear();
      setState(() {
        _index = 0;
        _letterVisible = true;
      });
      return;
    }
    _drawingController.clear();
    setState(() {
      _index += 1;
      _letterVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == widget.cards.length - 1;
    final compact = MediaQuery.sizeOf(context).shortestSide < 600;
    return LayoutBuilder(
      builder: (context, constraints) {
        final prompt = Container(
          key: const ValueKey('practice-reference'),
          height: _card.spokenOnly
              ? (constraints.maxHeight * .45).clamp(180.0, 360.0)
              : compact
              ? (constraints.maxHeight * .18).clamp(120.0, 150.0)
              : (constraints.maxHeight * .28).clamp(120.0, 220.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RecallPalette.of(context).soft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RecallPalette.of(context).line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Visibility(
                          visible: _cue != null || _letterVisible,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: LayoutBuilder(
                            builder: (context, space) => FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: space.maxWidth,
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
                                    height: 1.2,
                                    fontWeight: FontWeight.w500,
                                    color: RecallPalette.of(context).ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _cue != null && !_letterVisible ? '' : _sound,
                        key: const ValueKey<String>('draw-practice-sound'),
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
                  PronunciationButton(
                    key: ValueKey<String>(
                      'draw-practice-audio-${_card.id}-${_cue?.storageKey}',
                    ),
                    autoPlay: _cue?.isListening == true,
                    audioUrl: audioUrl,
                    repository: widget.audioRepository!,
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        );
        final practice = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        );
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.title} · Focus'),
            leading: IconButton(
              tooltip: 'Back to study sheet',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, bodyConstraints) => SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: bodyConstraints.maxHeight.clamp(
                        500.0,
                        double.infinity,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'CARD ${_index + 1} OF ${widget.cards.length}',
                                      key: const ValueKey<String>(
                                        'draw-practice-progress',
                                      ),
                                      style: monoLabel,
                                    ),
                                    const Spacer(),
                                    if (compact)
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    LanguageExamplesPage(
                                                      card: _card,
                                                      audioRepository: widget
                                                          .audioRepository,
                                                      backLabel: 'Practice',
                                                    ),
                                              ),
                                            ),
                                        child: const Text('Examples'),
                                      )
                                    else
                                      Text(
                                        'Practice only',
                                        style: monoLabel.copyWith(
                                          color: RecallColors.faint,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      prompt,
                                      const SizedBox(height: 16),
                                      if (!_card.spokenOnly)
                                        Expanded(child: practice)
                                      else
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              'Listen and say it aloud',
                                              style: TextStyle(
                                                color: RecallPalette.of(
                                                  context,
                                                ).muted,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  runSpacing: 8,
                                  children: [
                                    if (!_card.spokenOnly)
                                      IconButton.filledTonal(
                                        tooltip: _letterVisible
                                            ? 'Hide character'
                                            : 'Show character',
                                        onPressed: () => setState(
                                          () =>
                                              _letterVisible = !_letterVisible,
                                        ),
                                        icon: Icon(
                                          _letterVisible
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    IconButton.filledTonal(
                                      tooltip: 'Study sheet',
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(
                                        Icons.view_list_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton.filledTonal(
                                      tooltip: 'Previous',
                                      onPressed: _index == 0
                                          ? null
                                          : () {
                                              _drawingController.clear();
                                              setState(() {
                                                _index--;
                                                _letterVisible = true;
                                              });
                                            },
                                      icon: const Icon(Icons.arrow_back),
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
                    if (!compact)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: TabletRecallContext(
                          key: ValueKey('practice-context-${_card.id}'),
                          card: _card,
                          allSizes: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
