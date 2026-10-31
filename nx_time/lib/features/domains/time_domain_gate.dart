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
                Text('Could not load domain: $e'),
                TextButton(
                  onPressed: () => ref.invalidate(timeDomainsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (w) => KeyedSubtree(
          key: ValueKey(
            '${w.user.preset.serverId}:${w.user.userId}:${w.selectedId}',
          ),
          child: child,
        ),
      );
}

Future<void> showTimeDomains(BuildContext context, WidgetRef ref) async {
  final w = await ref.read(timeDomainsProvider.future);
  if (!context.mounted) return;
  final result = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Choose domain'),
      children: [
        for (final d in w.memberships)
          ListTile(
            title: Text(d.name),
            subtitle: d.writable ? null : const Text('Read only'),
            trailing: d.id == w.selectedId ? const Icon(Icons.check) : null,
            selected: d.id == w.selectedId,
            onTap: () => Navigator.pop(context, d.id),
          ),
      ],
    ),
  );
  if (result == null || result == w.selectedId || !context.mounted) return;
  await ref.read(timeDomainsProvider.notifier).select({result});
  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
}

/// New records belong to the active domain; relationships stay in that domain.
Future<int?> chooseCreationDomain(
  BuildContext context,
  WidgetRef ref, {
  int? relatedId,
}) async {
  final w = await ref.read(timeDomainsProvider.future);
  if (relatedId != null) return w.owner(relatedId, write: true);
  w.writable(w.selectedId);
  return w.selectedId;
}
