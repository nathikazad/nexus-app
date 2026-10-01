import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/study/language/language_examples_page.dart';
import 'package:nx_cards/study/language/drawing/open_sheet_drawing.dart';

class LanguageStudyPage extends ConsumerStatefulWidget {
  const LanguageStudyPage({
    super.key,
    required this.title,
    required this.cards,
    this.itemLabel,
    this.cues,
  });

  final String title;
  final List<StudyCard> cards;
  final String? itemLabel;
  final List<StudyCue>? cues;

  @override
  ConsumerState<LanguageStudyPage> createState() => _LanguageStudyPageState();
}

class _LanguageStudyPageState extends ConsumerState<LanguageStudyPage> {
  final AudioPlayer _player = AudioPlayer();
  final _scroll = ScrollController();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  int? _activeCardId;
  int? _loadingCardId;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll([
      _player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _playing = state == PlayerState.playing);
      }),
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _activeCardId = null;
        });
      }),
    ]);
  }

  Future<void> _toggleAudio(
    StudyCard card,
    String audioUrl,
    CardAudioRepository repository,
  ) async {
    if (_loadingCardId != null) return;
    if (_activeCardId == card.id) {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }

    setState(() => _loadingCardId = card.id);
    try {
      await _player.stop();
      final bytes = await repository.fetch(audioUrl);
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(languageAudioSource(bytes));
      if (!mounted) return;
      setState(() {
        _activeCardId = card.id;
        _playing = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play pronunciation')),
      );
    } finally {
      if (mounted) setState(() => _loadingCardId = null);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioRepository = ref.watch(cardAudioRepositoryProvider);
    final cards = widget.cards;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('End'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            itemCount: cards.length + 2,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 10)
                : const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _StudySheetHeader(
                  total: widget.cards.length,
                  itemLabel: widget.itemLabel ?? 'words',
                );
              }
              if (index == cards.length + 1) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Return'),
                      ),
                    ],
                  ),
                );
              }
              final card = cards[index - 1];
              final content = card.content;
              return _StudySheetRow(
                number: index,
                onDraw: content is! LanguageCardContent
                    ? null
                    : () async {
                        if (_activeCardId != null) await _player.stop();
                        if (!context.mounted) return;
                        final drawingCards = cards
                            .where((c) => c.isLanguageCard)
                            .toList();
                        await openSheetDrawing(
                          context,
                          ref,
                          widget.title,
                          drawingCards,
                          drawingCards.indexWhere((c) => c.id == card.id),
                        );
                      },
                cue: widget.cues?[index - 1],
                card: card,
                content: content,
                audioRepository: audioRepository,
                loading: _loadingCardId == card.id,
                playing: _activeCardId == card.id && _playing,
                onAudio:
                    content is! LanguageCardContent ||
                        audioRepository == null ||
                        content.audioUrl?.isNotEmpty != true
                    ? null
                    : () => _toggleAudio(
                        card,
                        content.audioUrl!,
                        audioRepository,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StudySheetHeader extends StatelessWidget {
  const _StudySheetHeader({required this.total, required this.itemLabel});

  final int total;
  final String itemLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('STUDY SHEET', style: monoLabel),
      const SizedBox(height: 7),
      Text(
        '$total $itemLabel',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
      ),
      const SizedBox(height: 12),
    ],
  );
}

class _StudySheetRow extends StatelessWidget {
  const _StudySheetRow({
    required this.number,
    required this.onDraw,
    this.cue,
    required this.card,
    required this.content,
    required this.audioRepository,
    required this.loading,
    required this.playing,
    required this.onAudio,
  });

  final int number;
  final VoidCallback? onDraw;
  final StudyCue? cue;
  final StudyCard card;
  final CardContent content;
  final CardAudioRepository? audioRepository;
  final bool loading;
  final bool playing;
  final VoidCallback? onAudio;
  LanguageCardContent? get languageContent =>
      content is LanguageCardContent ? content as LanguageCardContent : null;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Text(number.toString().padLeft(2, '0'), style: monoLabel),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageContent?.originalScript ?? content.back,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (languageContent case final word?) ...[
                Text(
                  word.transliteration,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                Text(
                  word.english,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ] else
                Text(
                  content.front,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onAudio != null)
              IconButton(
                tooltip: playing ? 'Pause pronunciation' : 'Play pronunciation',
                onPressed: loading ? null : onAudio,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
              ),
            if (onDraw != null)
              IconButton(
                tooltip: 'Draw',
                onPressed: onDraw,
                color: Colors.blue,
                icon: const Icon(Icons.draw_outlined, size: 20),
              ),
            if (languageContent?.examples.isNotEmpty == true)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LanguageExamplesPage(
                      card: card,
                      audioRepository: audioRepository,
                    ),
                  ),
                ),
                child: const Text('Examples'),
              ),
          ],
        ),
      ],
    ),
  );
}
