import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';

class TimeDomainGate extends ConsumerWidget {
  const TimeDomainGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(timeDomainsProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load domains: $e'),
                TextButton(
                  onPressed: () => ref.invalidate(timeDomainsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (w) => w.needsSelection
            ? const _InitialDomains()
            : KeyedSubtree(
                key: ValueKey(
                  '${w.user.preset.serverId}:${w.user.userId}:${w.selectedIds.join(",")}',
                ),
                child: child,
              ),
      );
}

Future<void> showTimeDomains(BuildContext context, WidgetRef ref) async {
  final w = await ref.read(timeDomainsProvider.future);
  final selected = {...w.selectedIds};
  if (!context.mounted) return;
  final result = await showDialog<Set<int>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Domains'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tasks, Calendar and Goals combine the domains you select. Today and History always use your personal domain.',
              ),
              for (final d in w.memberships)
                CheckboxListTile(
                  value: selected.contains(d.id),
                  title: Text(d.name),
                  subtitle: Text(
                    '${d.id == w.personalId ? 'Personal' : 'Shared'}${d.writable ? '' : ' · Read only'}',
                  ),
                  onChanged: (v) => setState(() {
                    if (v == true)
                      selected.add(d.id);
                    else
                      selected.remove(d.id);
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, selected),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
  if (result != null) {
    await ref.read(timeDomainsProvider.notifier).select(result);
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

/// Every creation chooses exactly one writable destination. Existing relationships
/// constrain the destination to their domain, never move those records implicitly.
Future<int?> chooseCreationDomain(
  BuildContext context,
  WidgetRef ref, {
  int? relatedId,
}) async {
  final w = await ref.read(timeDomainsProvider.future);
  if (relatedId != null) return w.owner(relatedId, write: true);
  final choices = w.memberships
      .where((d) => w.selectedIds.contains(d.id) && d.writable)
      .toList();
  if (choices.isEmpty) throw StateError('No selected domain allows creation');
  if (choices.length == 1) return choices.single.id;
  if (!context.mounted) return null;
  return showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Create in which domain?'),
      children: [
        for (final d in choices)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, d.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(d.name),
            ),
          ),
      ],
    ),
  );
}

class _InitialDomains extends ConsumerStatefulWidget {
  const _InitialDomains();
  @override
  ConsumerState<_InitialDomains> createState() => _InitialDomainsState();
}

class _InitialDomainsState extends ConsumerState<_InitialDomains> {
  Set<int>? selected;
  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final w = ref.watch(timeDomainsProvider).requireValue;
    selected ??= {...w.selectedIds};
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your domains')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Select the domains to show together in Tasks, Calendar and Goals. Today and History always use your personal domain.',
          ),
          const SizedBox(height: 16),
          for (final d in w.memberships)
            CheckboxListTile(
              value: selected!.contains(d.id),
              title: Text(d.name),
              subtitle: Text(
                '${d.id == w.personalId ? 'Personal' : 'Shared'}${d.writable ? '' : ' · Read only'}',
              ),
              onChanged: saving
                  ? null
                  : (v) => setState(() {
                      if (v == true)
                        selected!.add(d.id);
                      else
                        selected!.remove(d.id);
                    }),
            ),
          if (error != null) Text(error!),
          FilledButton(
            onPressed: saving || selected!.isEmpty
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      await ref
                          .read(timeDomainsProvider.notifier)
                          .select(selected!);
                    } catch (e) {
                      if (mounted)
                        setState(() {
                          saving = false;
                          error = e.toString();
                        });
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Continue'),
          ),
        ],
      ),
    );
  }
}
