import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_people/data/sync/people_data_repository.dart';
import 'package:nx_people/data/sync/people_sync_providers.dart';

final peoplePendingProvider = FutureProvider<List<PendingMutation>>((ref) {
  ref.watch(peopleDataGenerationProvider);
  return ref.watch(peopleOfflineStoreProvider)?.pendingMutations() ??
      Future.value([]);
});

class PeopleSyncStatus extends ConsumerWidget {
  const PeopleSyncStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(peoplePendingProvider).value ?? [];
    if (pending.isEmpty) return const SizedBox.shrink();
    final blocked = pending.any(
      (m) => m.status == PendingMutationStatus.blocked,
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: ListTile(
        dense: true,
        title: Text(
          blocked
              ? 'Some saved edits need review'
              : '${pending.length} changes saved on this device',
        ),
        subtitle: Text(
          blocked ? 'Tap to review before syncing' : 'Will sync when connected',
        ),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _PendingSheet(),
        ),
      ),
    );
  }
}

class _PendingSheet extends ConsumerWidget {
  const _PendingSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(peoplePendingProvider).value ?? [];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Saved changes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty) const Text('All changes have synced.'),
            for (final mutation in pending)
              ListTile(
                title: Text(
                  (mutation.payload['command'] as Map)['name']?.toString() ??
                      'Record update',
                ),
                subtitle: Text(mutation.lastError ?? 'Waiting to sync'),
                onTap: mutation.status == PendingMutationStatus.blocked
                    ? () => _review(context, ref, mutation)
                    : null,
              ),
            TextButton(
              onPressed: () => ref.read(peopleOutboxProvider)?.schedule(),
              child: const Text('Try syncing now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    PendingMutation mutation,
  ) async {
    final store = ref.read(peopleOfflineStoreProvider)!;
    final encoded = await store.library.read(
      'people_conflicts',
      mutation.operationId,
    );
    final local = await store.get(mutation.payload['local_id'] as String);
    if (!context.mounted) return;
    if (encoded == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit needs attention'),
          content: Text(mutation.lastError ?? 'Unable to sync this edit.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final remote = jsonDecode(encoded)['entity'];
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review conflicting changes'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your saved version'),
              SelectableText(_readable(local)),
              const SizedBox(height: 16),
              const Text('Server version'),
              SelectableText(
                remote == null ? 'This record was deleted.' : _readable(remote),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Use server version'),
          ),
          if (remote != null)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keep my changes'),
            ),
        ],
      ),
    );
    if (keep == null) return;
    try {
      await store.resolveConflict(
        mutation.operationId,
        keepLocal: keep,
        replacementId: peopleOperationId(),
      );
      if (context.mounted) ref.read(peopleOutboxProvider)?.schedule();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _readable(dynamic value) {
    if (value is! Map) return 'Deleted locally';
    return const JsonEncoder.withIndent('  ').convert({
      for (final key in value.keys)
        if (!{
              'id',
              'revision',
              'created_at',
              'updated_at',
              'model_type_id',
              'model_type',
              'kind',
            }.contains(key) &&
            value[key] != null)
          key: value[key],
    });
  }
}
