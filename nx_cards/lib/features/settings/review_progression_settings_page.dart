import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/features/settings/review_progression_settings.dart';

class ReviewProgressionSettingsPage extends ConsumerWidget {
  const ReviewProgressionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reviewProgressionSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Review settings')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load settings: $error')),
        data: (value) => _SettingsForm(initial: value),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});

  final ReviewProgressionSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late bool _automaticProgression = widget.initial.automaticProgressionEnabled;
  late int _historyWindow = widget.initial.historyWindow;
  late int _pastPercentage = widget.initial.moveToPastPercentage;
  late int _currentPercentage = widget.initial.moveToCurrentPercentage;
  late bool _autoReplace = widget.initial.autoReplacePromotedCards;
  bool _saving = false;

  bool get _valid => _currentPercentage < _pastPercentage;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final settings = ReviewProgressionSettings(
      automaticProgressionEnabled: _automaticProgression,
      historyWindow: _historyWindow,
      moveToPastPercentage: _pastPercentage,
      moveToCurrentPercentage: _currentPercentage,
      autoReplacePromotedCards: _autoReplace,
    );
    try {
      await ref.read(reviewProgressionSettingsStoreProvider).save(settings);
      ref.invalidate(reviewProgressionSettingsProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Review progression',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              const Text(
                'Control how cards move between Current, Past, and Future.',
                style: TextStyle(color: RecallColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              _SettingsCard(
                child: DropdownButtonFormField<int>(
                  initialValue: _historyWindow,
                  decoration: const InputDecoration(
                    labelText: 'Recent answers to consider',
                  ),
                  items: const [3, 5, 7, 10]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('Last $value answers'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _historyWindow = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Automatic progression'),
                  subtitle: const Text(
                    'Update learning lists after graded sessions.',
                    style: TextStyle(color: RecallColors.muted, fontSize: 12),
                  ),
                  value: _automaticProgression,
                  onChanged: (value) =>
                      setState(() => _automaticProgression = value),
                ),
              ),
              if (_automaticProgression) ...[
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Column(
                    children: [
                      _PercentageSetting(
                        title: 'Move to Past',
                        detail: 'when recall is at least',
                        value: _pastPercentage,
                        color: RecallColors.emerald,
                        onChanged: (value) =>
                            setState(() => _pastPercentage = value),
                      ),
                      const Divider(height: 30),
                      _PercentageSetting(
                        title: 'Move to Current',
                        detail: 'when recall is at or below',
                        value: _currentPercentage,
                        color: RecallColors.orange,
                        onChanged: (value) =>
                            setState(() => _currentPercentage = value),
                      ),
                      if (!_valid) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'The Current threshold must be lower than the Past threshold.',
                          style: TextStyle(
                            color: RecallColors.rose,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Keep Current list filled'),
                    subtitle: const Text(
                      'For every word moved from Current to Past, add the next Future word in the same category.',
                      style: TextStyle(color: RecallColors.muted, fontSize: 12),
                    ),
                    value: _autoReplace,
                    onChanged: (value) => setState(() => _autoReplace = value),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _valid && !_saving ? _save : null,
                child: Text(_saving ? 'Saving…' : 'Save settings'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _PercentageSetting extends StatelessWidget {
  const _PercentageSetting({
    required this.title,
    required this.detail,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String title;
  final String detail;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: RecallColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$value%',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      Slider(
        value: value.toDouble(),
        min: 0,
        max: 100,
        divisions: 20,
        activeColor: color,
        onChanged: (next) => onChanged(next.round()),
      ),
    ],
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: RecallColors.line),
    ),
    child: child,
  );
}
