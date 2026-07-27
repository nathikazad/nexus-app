import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/core/theme/app_theme.dart';

typedef HardRefetchCallback = Future<void> Function();

class NotesSettingsButton extends ConsumerWidget {
  const NotesSettingsButton({this.onHardRefetch, super.key});

  final HardRefetchCallback? onHardRefetch;

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
            onHardRefetch:
                onHardRefetch ??
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
    required this.onHardRefetch,
  });

  final bool offlineEnabled;
  final HardRefetchCallback onHardRefetch;

  @override
  ConsumerState<_NotesSettingsDialog> createState() =>
      _NotesSettingsDialogState();
}

class _NotesSettingsDialogState extends ConsumerState<_NotesSettingsDialog> {
  var _refetching = false;
  String? _resultMessage;
  var _failed = false;

  Future<void> _hardRefetch() async {
    if (_refetching) return;
    setState(() {
      _refetching = true;
      _resultMessage = null;
      _failed = false;
    });
    try {
      await widget.onHardRefetch();
      if (!mounted) return;
      setState(() {
        _resultMessage = widget.offlineEnabled
            ? 'Full library downloaded.'
            : 'Library refreshed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _resultMessage = 'Refetch failed: $error';
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
    return AlertDialog(
      title: const Text('Settings'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
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
                  ? 'Download the complete document library again. '
                        'Local pending edits are preserved.'
                  : 'Reload the document library from the server.',
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('hard-refetch-button'),
              onPressed: _refetching ? null : _hardRefetch,
              icon: _refetching
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                _refetching
                    ? 'Refetching…'
                    : widget.offlineEnabled
                    ? 'Hard refetch'
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
          ],
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
