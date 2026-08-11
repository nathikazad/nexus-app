import 'package:flutter/material.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/cards_models.dart';

class ScriptDrawPracticePage extends StatefulWidget {
  const ScriptDrawPracticePage({
    super.key,
    required this.title,
    required this.cards,
  }) : assert(cards.length > 0);

  final String title;
  final List<StudyCard> cards;

  @override
  State<ScriptDrawPracticePage> createState() => _ScriptDrawPracticePageState();
}

class _ScriptDrawPracticePageState extends State<ScriptDrawPracticePage> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  int _index = 0;

  StudyCard get _card => widget.cards[_index];

  String get _letter {
    final content = _card.content;
    return content is LanguageCardContent ? content.originalScript : _card.back;
  }

  String get _sound {
    final content = _card.content;
    return content is LanguageCardContent ? content.english : _card.front;
  }

  void _startStroke(DragStartDetails details) {
    setState(() => _strokes.add(<Offset>[details.localPosition]));
  }

  void _extendStroke(DragUpdateDetails details) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(details.localPosition));
  }

  void _erase() => setState(_strokes.clear);

  void _next() {
    if (_index == widget.cards.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index += 1;
      _strokes.clear();
    });
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
                        'LETTER ${_index + 1} OF ${widget.cards.length}',
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
                    height: 148,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RecallColors.soft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RecallColors.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _letter,
                                key: const ValueKey<String>(
                                  'draw-practice-letter',
                                ),
                                style: const TextStyle(
                                  fontSize: 82,
                                  height: 1,
                                  fontWeight: FontWeight.w500,
                                  color: RecallColors.ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _sound,
                            key: const ValueKey<String>('draw-practice-sound'),
                            maxLines: 1,
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
                  ),
                  const SizedBox(height: 16),
                  Text('PRACTICE', style: monoLabel),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Semantics(
                      label: 'Drawing area for $_letter',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GestureDetector(
                          key: const ValueKey<String>('script-drawing-canvas'),
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _startStroke,
                          onPanUpdate: _extendStroke,
                          child: CustomPaint(
                            key: const ValueKey<String>('script-drawing-paint'),
                            foregroundPainter: _StrokePainter(_strokes),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: RecallColors.line),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _strokes.isEmpty ? null : _erase,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Erase'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _next,
                          icon: Icon(
                            last
                                ? Icons.check_circle_outline
                                : Icons.arrow_forward,
                          ),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(last ? 'Finish' : 'Next'),
                          ),
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

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RecallColors.ink
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawLine(
          stroke.first,
          stroke.first + const Offset(0.01, 0.01),
          paint,
        );
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
