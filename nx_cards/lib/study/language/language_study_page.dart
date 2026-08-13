import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_audio_controls.dart';
import 'package:nx_cards/study/language/language_examples_page.dart';

class LanguageStudyPage extends ConsumerStatefulWidget {
  const LanguageStudyPage({
    super.key,
    required this.title,
    required this.cards,
    this.itemLabel,
  });

  final String title;
  final List<StudyCard> cards;
  final String? itemLabel;

  @override
  ConsumerState<LanguageStudyPage> createState() => _LanguageStudyPageState();
}

class _LanguageStudyPageState extends ConsumerState<LanguageStudyPage> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  String _query = '';
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

  List<StudyCard> get _visibleCards {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.cards;
    return widget.cards
        .where((card) {
          final content = card.content;
          return content.front.toLowerCase().contains(query) ||
              content.back.toLowerCase().contains(query) ||
              (content is LanguageCardContent &&
                  content.transliteration.toLowerCase().contains(query));
        })
        .toList(growable: false);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioRepository = ref.watch(cardAudioRepositoryProvider);
    final cards = _visibleCards;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            itemCount: cards.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 10)
                : const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _StudySheetHeader(
                  total: widget.cards.length,
                  visible: cards.length,
                  itemLabel: widget.itemLabel ?? 'words',
                  onSearch: (value) => setState(() => _query = value),
                );
              }
              final card = cards[index - 1];
              final content = card.content;
              return _StudySheetRow(
                number: index,
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
  const _StudySheetHeader({
    required this.total,
    required this.visible,
    required this.itemLabel,
    required this.onSearch,
  });

  final int total;
  final int visible;
  final String itemLabel;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('STUDY SHEET', style: monoLabel),
      const SizedBox(height: 7),
      Text(
        visible == total
            ? '$total $itemLabel'
            : '$visible of $total $itemLabel',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        onChanged: onSearch,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search',
          prefixIcon: Icon(Icons.search, size: 20),
        ),
      ),
      const SizedBox(height: 12),
    ],
  );
}

class _StudySheetRow extends StatelessWidget {
  const _StudySheetRow({
    required this.number,
    required this.card,
    required this.content,
    required this.audioRepository,
    required this.loading,
    required this.playing,
    required this.onAudio,
  });

  final int number;
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
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              content.front,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
                color: RecallColors.muted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.back,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (languageContent case final languageContent?) ...[
                const SizedBox(height: 3),
                Text(
                  languageContent.transliteration,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                    color: RecallColors.faint,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                height: 34,
                child: onAudio == null
                    ? null
                    : IconButton(
                        tooltip: playing
                            ? 'Pause pronunciation'
                            : 'Play pronunciation',
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                        padding: const EdgeInsets.all(6),
                        style: IconButton.styleFrom(
                          foregroundColor: RecallColors.ink,
                        ),
                        onPressed: loading ? null : onAudio,
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                      ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 24,
                child:
                    languageContent == null || languageContent!.examples.isEmpty
                    ? null
                    : TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: RecallColors.muted,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 11),
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
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
