import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/cards_models.dart';

class CreateDeckDialog extends ConsumerStatefulWidget {
  const CreateDeckDialog({super.key});

  @override
  ConsumerState<CreateDeckDialog> createState() => _CreateDeckDialogState();
}

class _CreateDeckDialogState extends ConsumerState<CreateDeckDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _fromLanguage = 'English';
  String? _toLanguage;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(cardsRepositoryProvider)
          .createDeck(
            name: _name.text.trim(),
            description: _description.text.trim(),
            fromLanguage: _toLanguage == null ? null : _fromLanguage,
            toLanguage: _toLanguage,
          );
      ref.invalidate(cardsDashboardProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addLanguage({required bool from}) async {
    final value = await _promptForTag(context, 'New language');
    if (value == null) return;
    await ref.read(cardsRepositoryProvider).addLanguage(value);
    ref.invalidate(languagesProvider);
    if (mounted) {
      setState(() {
        if (from) {
          _fromLanguage = value;
        } else {
          _toLanguage = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownLanguages =
        ref.watch(languagesProvider).value ?? const <String>[];
    final languages = <String>{
      ...knownLanguages,
      'English',
      ?_fromLanguage,
      ?_toLanguage,
    }.toList()..sort();
    return AlertDialog(
      title: const Text('New deck'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _fromLanguage,
              decoration: const InputDecoration(labelText: 'From language'),
              items: [
                for (final language in languages)
                  DropdownMenuItem(value: language, child: Text(language)),
              ],
              onChanged: (value) => setState(() => _fromLanguage = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _toLanguage,
              decoration: const InputDecoration(
                labelText: 'To language (optional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not a language deck'),
                ),
                for (final language in languages)
                  DropdownMenuItem(value: language, child: Text(language)),
              ],
              onChanged: (value) => setState(() => _toLanguage = value),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : () => _addLanguage(from: false),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add language'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Creating…' : 'Create deck'),
        ),
      ],
    );
  }
}

class CardEditorDialog extends ConsumerStatefulWidget {
  const CardEditorDialog({super.key, required this.deck, this.card});

  final CardDeck deck;
  final StudyCard? card;

  @override
  ConsumerState<CardEditorDialog> createState() => _CardEditorDialogState();
}

class _CardEditorDialogState extends ConsumerState<CardEditorDialog> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  late final TextEditingController _transliteration;
  int? _bookId;
  bool _saving = false;

  bool get _isLanguageCard =>
      widget.card?.isLanguageCard ?? widget.deck.isLanguageDeck;

  @override
  void initState() {
    super.initState();
    _front = TextEditingController(text: widget.card?.front ?? '');
    _back = TextEditingController(text: widget.card?.back ?? '');
    final content = widget.card?.content;
    _transliteration = TextEditingController(
      text: content is LanguageCardContent ? content.transliteration : '',
    );
    _bookId = widget.card?.sourceBookId;
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _transliteration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_front.text.trim().isEmpty ||
        _back.text.trim().isEmpty ||
        (_isLanguageCard && _transliteration.text.trim().isEmpty)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(cardsRepositoryProvider);
      final existingLanguageContent = switch (widget.card?.content) {
        final LanguageCardContent content => content,
        _ => null,
      };
      final content = _isLanguageCard
          ? LanguageCardContent(
              english: _front.text.trim(),
              originalScript: _back.text.trim(),
              transliteration: _transliteration.text.trim(),
              audioUrl: existingLanguageContent?.audioUrl,
              examples:
                  existingLanguageContent?.examples ??
                  const <LanguageExample>[],
            )
          : BasicCardContent(
              front: _front.text.trim(),
              back: _back.text.trim(),
            );
      if (widget.card == null) {
        await repository.createCard(
          content: content,
          deckId: widget.deck.id,
          sourceBookId: _bookId,
        );
      } else {
        await repository.updateCardContent(
          id: widget.card!.id,
          content: content,
        );
      }
      ref.invalidate(cardsDashboardProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books =
        ref.watch(relatedBooksProvider).value ?? const <RelatedBook>[];
    return AlertDialog(
      title: Text(widget.card == null ? 'New card' : 'Edit card'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.deck.name, style: monoLabel),
              const SizedBox(height: 12),
              TextField(
                controller: _front,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _isLanguageCard
                      ? widget.deck.fromLanguage
                      : 'Front',
                  hintText: _isLanguageCard
                      ? 'Word or phrase in ${widget.deck.fromLanguage}'
                      : 'What should you recall?',
                ),
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _back,
                decoration: InputDecoration(
                  labelText: _isLanguageCard ? widget.deck.toLanguage : 'Back',
                  hintText: _isLanguageCard
                      ? 'Word or phrase in ${widget.deck.toLanguage}'
                      : 'The answer',
                ),
                minLines: 3,
                maxLines: 8,
              ),
              if (_isLanguageCard) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _transliteration,
                  decoration: const InputDecoration(
                    labelText: 'Transliteration',
                    hintText: 'Pronunciation in Latin script',
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ],
              if (widget.card == null && books.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: _bookId,
                  decoration: const InputDecoration(
                    labelText: 'Source book (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No source book'),
                    ),
                    for (final book in books)
                      DropdownMenuItem(value: book.id, child: Text(book.name)),
                  ],
                  onChanged: (value) => setState(() => _bookId = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save card'),
        ),
      ],
    );
  }
}

Future<String?> _promptForTag(BuildContext context, String title) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}
