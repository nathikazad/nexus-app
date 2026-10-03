import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/data/domains/domain_appearance.dart';

class DomainAppearancePage extends ConsumerStatefulWidget {
  const DomainAppearancePage({super.key});
  @override
  ConsumerState<DomainAppearancePage> createState() =>
      _DomainAppearancePageState();
}

class _DomainAppearancePageState extends ConsumerState<DomainAppearancePage> {
  Map<int, DomainAppearance>? draft;
  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(domainAppearancesProvider);
    final w = ref.watch(timeDomainsProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Domain appearance')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load preferences: $e')),
        data: (values) {
          draft ??= {...values};
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Your labels and colors apply only to you. Each domain has a marker color and a second color used as a faint background.',
              ),
              for (final entry in draft!.entries) ...[
                const SizedBox(height: 24),
                Text(
                  w!.name(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextFormField(
                  enabled: !saving,
                  initialValue: entry.value.label,
                  decoration: const InputDecoration(labelText: 'My label'),
                  onChanged: (v) => _update(entry.key, label: v),
                ),
                TextFormField(
                  enabled: !saving,
                  initialValue: entry.value.description,
                  decoration: const InputDecoration(
                    labelText: 'What this domain means to me',
                  ),
                  onChanged: (v) => _update(entry.key, description: v),
                ),
                const SizedBox(height: 12),
                _colors(entry.key, 'Marker color', entry.value.accent, false),
                _colors(
                  entry.key,
                  'Background accent',
                  entry.value.secondary,
                  true,
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (draft!.values.any((v) => v.label.trim().isEmpty)) {
                          setState(() => error = 'Each domain needs a label');
                          return;
                        }
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await saveDomainAppearances(ref, draft!);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) setState(() => error = '$e');
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _update(
    int id, {
    String? label,
    String? description,
    Color? accent,
    Color? secondary,
  }) {
    final old = draft![id]!;
    setState(
      () => draft![id] = DomainAppearance(
        label: label ?? old.label,
        description: description ?? old.description,
        accent: accent ?? old.accent,
        secondary: secondary ?? old.secondary,
      ),
    );
  }

  Widget _colors(int id, String label, Color value, bool secondary) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      Wrap(
        spacing: 8,
        children: [
          for (final color in {value, ...DomainAppearance.palette})
            IconButton(
              tooltip: '$label ${DomainAppearance.hex(color)}',
              onPressed: saving
                  ? null
                  : () => _update(
                      id,
                      accent: secondary ? null : color,
                      secondary: secondary ? color : null,
                    ),
              icon: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: color == value
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    ],
  );
}
