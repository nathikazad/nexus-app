import 'package:flutter/material.dart';
import 'package:nx_cards/browser/browser.dart';

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
      title: const Text('Edit card'),
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
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    minLines: 1,
    maxLines: 5,
    decoration: InputDecoration(labelText: label),
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? 'Enter the ${label.toLowerCase()}.'
              : null
        : null,
  );
}
