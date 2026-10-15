import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/sync/sync_providers.dart';
import 'package:nx_cards/sync/native/local_cards_store.dart';

final syncDiagnosticsProvider = FutureProvider.autoDispose<String>((ref) async {
  final store = ref.watch(localCardsStoreProvider);
  if (store == null) {
    return 'Local upload queue is unavailable in this session.';
  }
  final pending = await store.pendingMutations();
  final times = store is CardsSyncDiagnosticsStore
      ? await (store as CardsSyncDiagnosticsStore).readSyncTimes()
      : <String, DateTime>{};
  final dashboard = await store.readDashboard();
  final upload = ref.read(cardsUploaderProvider)?.status;
  String timestamp(String key) =>
      times[key]?.toLocal().toIso8601String() ?? 'Not recorded yet';
  final now = DateTime.now();
  final report = StringBuffer()
    ..writeln('NX Cards sync diagnostics')
    ..writeln('Captured: ${now.toIso8601String()}')
    ..writeln('Time zone: ${now.timeZoneName} (${now.timeZoneOffset})')
    ..writeln('Cards stored: ${dashboard.cards.length}')
    ..writeln('Last successful upload: ${timestamp('sent')}')
    ..writeln('Last successful server sync: ${timestamp('received')}')
    ..writeln(
      'Upload time records an accepted card change. Server sync time includes checks with no changed cards.',
    )
    ..writeln(
      'Times are saved on this device for the current account and domain. Earlier activity cannot be reconstructed.',
    )
    ..writeln('Upload activity: ${upload?.activity.name ?? 'unavailable'}')
    ..writeln('Pending card changes: ${pending.length}')
    ..writeln('A card change can contain multiple reviews.');
  if (upload?.message != null) {
    report.writeln('Upload status: ${upload!.message}');
  }
  if (pending.isEmpty) {
    report.writeln('No uploads are waiting on this device.');
  }
  for (final item in pending) {
    report
      ..writeln()
      ..writeln('Card ${item.entityKey.remoteId} · ${item.type.name}')
      ..writeln('Status: ${item.status.name}')
      ..writeln('Attempts: ${item.attemptCount}')
      ..writeln('Created: ${item.createdAt.toLocal().toIso8601String()}');
    if (item.nextAttemptAt != null) {
      report.writeln(
        'Next attempt: ${item.nextAttemptAt!.toLocal().toIso8601String()}',
      );
    }
    if (item.leaseExpiresAt != null) {
      report.writeln(
        'Upload lease expires: ${item.leaseExpiresAt!.toLocal().toIso8601String()}',
      );
    }
    if (item.lastError != null) report.writeln('Last error: ${item.lastError}');
  }
  return report.toString();
}, retry: (_, _) => null);

class SyncDiagnosticsPage extends StatelessWidget {
  const SyncDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sync diagnostics')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: _DiagnosticsReport(),
    ),
  );
}

class _DiagnosticsReport extends ConsumerWidget {
  const _DiagnosticsReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(syncDiagnosticsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: report.isLoading
                  ? null
                  : () => ref.invalidate(syncDiagnosticsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            TextButton.icon(
              onPressed: report.hasValue
                  ? () async {
                      await Clipboard.setData(
                        ClipboardData(text: report.requireValue),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sync report copied')),
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.copy),
              label: const Text('Copy report'),
            ),
          ],
        ),
        report.when(
          skipLoadingOnRefresh: false,
          data: (text) => SelectableText(text),
          error: (error, _) => Text('Could not read upload queue: $error'),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}
