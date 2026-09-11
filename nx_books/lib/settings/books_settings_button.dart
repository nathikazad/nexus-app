import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:nx_books/core/theme/app_theme.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_books/settings/books_preferences.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_offline/nx_offline.dart';
import 'download_report_view.dart';

class BooksSettingsButton extends ConsumerWidget {
  const BooksSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x18000000), blurRadius: 8),
        ],
      ),
      child: IconButton(
        key: const ValueKey<String>('books-settings-button'),
        tooltip: 'Settings',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => const _BooksSettingsDialog(),
        ),
        icon: const Icon(Icons.settings_outlined, size: 19),
      ),
    );
  }
}

class _BooksSettingsDialog extends ConsumerStatefulWidget {
  const _BooksSettingsDialog();

  @override
  ConsumerState<_BooksSettingsDialog> createState() =>
      _BooksSettingsDialogState();
}

class _BooksSettingsDialogState extends ConsumerState<_BooksSettingsDialog> {
  var _refreshing = false;
  String? _syncMessage;
  String? _accountMessage;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _syncMessage = null;
    });
    try {
      final sync = ref.read(booksLibrarySyncProvider);
      if (sync != null) {
        await sync.requestFull(SyncReason.manual);
      } else {
        ref
          ..invalidate(booksProvider)
          ..invalidate(topicTagsProvider);
        await Future.wait([
          ref.read(booksProvider.future),
          ref.read(topicTagsProvider.future),
        ]);
      }
      if (mounted) setState(() => _syncMessage = 'Library synchronized.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _syncMessage =
              'Sync could not finish. Downloaded content is retained. Try again when online.',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _logout() async {
    Navigator.of(context).pop();
    await ref.read(authProvider.notifier).logout();
  }

  Future<void> _copyAccessToken() async {
    try {
      final token = await nexusOidcService.accessToken();
      await Clipboard.setData(ClipboardData(text: token));
      if (mounted) {
        setState(
          () => _accountMessage =
              'Access token copied. It expires automatically.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _accountMessage = 'Could not copy the access token.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(booksDarkModeProvider);
    final textScale = ref.watch(booksTextScaleProvider);
    final user = ref.watch(authProvider).value;
    final bookFileReport = ref.watch(bookFileReportProvider).value;
    final supervisor = ref.watch(booksLibrarySyncProvider);
    final status =
        ref.watch(booksSyncStatusProvider).value ?? supervisor?.status;
    final syncing = supervisor == null
        ? _refreshing
        : status?.activity == SyncActivity.syncing;
    return AlertDialog(
      title: const Text('Settings'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Appearance', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                key: const ValueKey<String>('books-theme-selector'),
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: <bool>{darkMode},
                onSelectionChanged: (selection) => ref
                    .read(booksDarkModeProvider.notifier)
                    .setDarkMode(selection.single),
              ),
              const SizedBox(height: 18),
              Text(
                'Reader text',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton.outlined(
                    key: const ValueKey<String>('books-text-smaller'),
                    onPressed: textScale > BooksTextScaleNotifier.minimumScale
                        ? ref.read(booksTextScaleProvider.notifier).decrease
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '${(textScale * 100).round()}%',
                      key: const ValueKey<String>('books-text-scale-value'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton.outlined(
                    key: const ValueKey<String>('books-text-larger'),
                    onPressed: textScale < BooksTextScaleNotifier.maximumScale
                        ? ref.read(booksTextScaleProvider.notifier).increase
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Offline library',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Refresh the bookshelf and download all changed books and documents for '
                'offline reading.',
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const ValueKey<String>('books-sync-now-button'),
                onPressed: syncing ? null : _refresh,
                icon: syncing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(syncing ? 'Synchronizing…' : 'Sync now'),
              ),
              const SizedBox(height: 8),
              DownloadReportView(
                report: ref.watch(downloadReportProvider).value,
                syncing: syncing,
              ),
              if (bookFileReport != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${bookFileReport.verified}/${bookFileReport.total} attached book files verified'
                  '${bookFileReport.failed.isEmpty ? '' : ' (${bookFileReport.failed.length} failed)'}.',
                ),
              ],
              if (_syncMessage != null) Text(_syncMessage!),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text('Account', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey<String>('books-logout-button'),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
              if (user?.preset.requiresOidc ?? false) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey<String>('books-copy-token-button'),
                  onPressed: _copyAccessToken,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Copy upload token'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use this short-lived token with the Mac upload script.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_accountMessage != null) ...[
                const SizedBox(height: 6),
                Text(_accountMessage!),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'App version',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              const Text('Version 1.0.0 (1)'),
              const SizedBox(height: 2),
              Text(
                'Base release',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
