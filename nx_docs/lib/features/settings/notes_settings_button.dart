import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/composition/app_version_provider.dart';
import 'package:nx_docs/composition/offline_providers.dart';
import 'package:nx_docs/core/version/app_version_info.dart';
import 'package:nx_docs/core/theme/app_theme.dart';
import 'package:nx_docs/features/editor/document_text_scale.dart';

typedef LibrarySyncCallback = Future<void> Function();

class NotesSettingsButton extends ConsumerWidget {
  const NotesSettingsButton({this.onSyncNow, super.key});

  final LibrarySyncCallback? onSyncNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineEnabled = ref.watch(offlineEnabledProvider);
    return IconButton(
      key: const Key('notes-settings-button'),
      tooltip: 'Settings',
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) => _NotesSettingsDialog(
            offlineEnabled: offlineEnabled,
            onSyncNow:
                onSyncNow ??
                () async {
                  await ref.read(notesLibraryRefreshProvider)();
                },
          ),
        );
      },
      style: IconButton.styleFrom(
        minimumSize: const Size.square(34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(Icons.settings_outlined, size: 19, color: AppColors.muted),
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    );
  }
}

class _NotesSettingsDialog extends ConsumerStatefulWidget {
  const _NotesSettingsDialog({
    required this.offlineEnabled,
    required this.onSyncNow,
  });

  final bool offlineEnabled;
  final LibrarySyncCallback onSyncNow;

  @override
  ConsumerState<_NotesSettingsDialog> createState() =>
      _NotesSettingsDialogState();
}

class _NotesSettingsDialogState extends ConsumerState<_NotesSettingsDialog> {
  var _refetching = false;
  String? _resultMessage;
  var _failed = false;

  Future<void> _syncNow() async {
    if (_refetching) return;
    setState(() {
      _refetching = true;
      _resultMessage = null;
      _failed = false;
    });
    try {
      await widget.onSyncNow();
      if (!mounted) return;
      setState(() {
        _resultMessage = widget.offlineEnabled
            ? 'Library synchronized.'
            : 'Library refreshed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _resultMessage = 'Sync failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _refetching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(appDarkModeProvider);
    final documentTextScale = ref.watch(documentTextScaleProvider);
    final versionInfo = ref.watch(appVersionInfoProvider);
    return AlertDialog(
      title: const Text('Settings'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Appearance', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                key: const Key('theme-mode-selector'),
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
                selected: <bool>{isDark},
                onSelectionChanged: (selection) {
                  ref
                      .read(appDarkModeProvider.notifier)
                      .setDarkMode(selection.single);
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Document text',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton.outlined(
                    key: const Key('document-text-smaller'),
                    tooltip: 'Make document text smaller (⌘−)',
                    onPressed:
                        documentTextScale >
                            DocumentTextScaleNotifier.minimumScale
                        ? ref.read(documentTextScaleProvider.notifier).decrease
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '${(documentTextScale * 100).round()}%',
                      key: const Key('document-text-scale-value'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton.outlined(
                    key: const Key('document-text-larger'),
                    tooltip: 'Make document text larger (⌘+)',
                    onPressed:
                        documentTextScale <
                            DocumentTextScaleNotifier.maximumScale
                        ? ref.read(documentTextScaleProvider.notifier).increase
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                widget.offlineEnabled ? 'Offline library' : 'Library',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(
                widget.offlineEnabled
                    ? 'Upload pending edits, compare the local manifest, and '
                          'download every changed document for offline use.'
                    : 'Reload the document library from the server.',
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('sync-now-button'),
                onPressed: _refetching ? null : _syncNow,
                icon: _refetching
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _refetching
                      ? 'Synchronizing…'
                      : widget.offlineEnabled
                      ? 'Sync now'
                      : 'Refresh library',
                ),
              ),
              if (_resultMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _resultMessage!,
                  style: TextStyle(
                    color: _failed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'App version',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              const Text('Version $kAppVersion ($kAppBuildNumber)'),
              const SizedBox(height: 2),
              Text(
                versionInfo.when(
                  data: (info) => info.patchLabel,
                  loading: () => 'Reading Shorebird patch…',
                  error: (_, _) => 'Shorebird patch status unavailable',
                ),
                key: const Key('shorebird-patch-version'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _refetching ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
