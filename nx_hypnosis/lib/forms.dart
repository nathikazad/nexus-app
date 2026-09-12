import 'package:flutter/material.dart';
import 'desires.dart';

class DesireForm extends StatefulWidget {
  const DesireForm({
    super.key,
    this.desire,
    required this.cancel,
    required this.save,
  });
  final Desire? desire;
  final VoidCallback cancel;
  final void Function(String, String) save;
  @override
  State<DesireForm> createState() => _DesireFormState();
}

class _DesireFormState extends State<DesireForm> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.desire?.title ?? '');
  late final belief = TextEditingController(text: widget.desire?.belief ?? '');
  @override
  void dispose() {
    title.dispose();
    belief.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.desire == null ? 'Add desire' : 'Edit desire',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 24),
      Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
              validator: requiredText,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: belief,
              decoration: const InputDecoration(
                labelText: 'What do you want to believe?',
                alignLabelWithHint: true,
              ),
              minLines: 7,
              maxLines: 12,
              validator: requiredText,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                FilledButton(
                  onPressed: () {
                    if (form.currentState!.validate()) {
                      widget.save(title.text.trim(), belief.text.trim());
                    }
                  },
                  child: const Text('Save desire'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: widget.cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Please fill in this field.' : null;

class StoryForm extends StatefulWidget {
  const StoryForm({
    super.key,
    required this.desires,
    required this.initial,
    required this.cancel,
    required this.create,
  });
  final List<Desire> desires;
  final String initial;
  final VoidCallback cancel;
  final void Function(String, String, String) create;
  @override
  State<StoryForm> createState() => _StoryFormState();
}

class _StoryFormState extends State<StoryForm> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final prompt = TextEditingController();
  late String selected = widget.initial;
  @override
  void dispose() {
    title.dispose();
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Create a story',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Desire',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      ...widget.desires.map(
        (d) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            selected: selected == d.id,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: selected == d.id
                    ? const Color(0xffeeeeec)
                    : Colors.white,
                side: BorderSide(
                  color: selected == d.id
                      ? const Color(0xff333333)
                      : const Color(0xffe2e2e0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () => setState(() => selected = d.id),
              child: Row(
                children: [
                  Icon(
                    selected == d.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(d.title, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: requiredText,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: prompt,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'What would you like to experience? (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'This prototype creates an editable sample, rather than generating a new story.',
              style: TextStyle(fontSize: 12, color: Color(0xff909090)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: () {
                    if (form.currentState!.validate()) {
                      widget.create(
                        selected,
                        title.text.trim(),
                        prompt.text.trim(),
                      );
                    }
                  },
                  child: const Text('Create sample story'),
                ),
                TextButton(
                  onPressed: widget.cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
