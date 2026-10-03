import 'package:flutter/material.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/app/theme.dart';

class CardEditDialog extends StatefulWidget {
  const CardEditDialog({super.key, required this.card, required this.library});
  final StudyCard card;
  final CardLibrary library;

  @override
  State<CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<CardEditDialog> {
  final _form = GlobalKey<FormState>();
  late final _front = TextEditingController(text: widget.card.content.front);
  late final _back = TextEditingController(text: widget.card.content.back);
  late final _transliteration = TextEditingController(
    text: widget.card.content is LanguageCardContent
        ? (widget.card.content as LanguageCardContent).transliteration
        : '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _transliteration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final old = widget.card.content;
    final content = old is LanguageCardContent
        ? old.copyWith(
            english: _front.text.trim(),
            originalScript: _back.text.trim(),
            transliteration: _transliteration.text.trim(),
          )
        : BasicCardContent(front: _front.text.trim(), back: _back.text.trim());
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.library.updateCardContent(
        id: widget.card.id,
        content: content,
      );
      if (mounted) Navigator.pop(context, content);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your changes. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CARD DETAILS',
            style: monoLabel.copyWith(color: RecallPalette.of(context).muted),
          ),
          const SizedBox(height: 8),
          const Text(
            'Edit card',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -.7,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field('Front', _front, required: true),
                const SizedBox(height: 16),
                _field('Back', _back, required: true),
                if (widget.card.content is LanguageCardContent) ...[
                  const SizedBox(height: 16),
                  _field('Transliteration', _transliteration),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: monoLabel.copyWith(
          color: RecallPalette.of(context).muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        enabled: !_saving,
        minLines: label == 'Transliteration' ? 1 : 2,
        maxLines: 5,
        style: TextStyle(
          fontSize: 17,
          height: 1.45,
          color: RecallPalette.of(context).ink,
        ),
        decoration: InputDecoration(
          hintText: label,
          filled: true,
          fillColor: RecallPalette.of(context).soft,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Enter the ${label.toLowerCase()}.'
                  : null
            : null,
      ),
    ],
  );
}
