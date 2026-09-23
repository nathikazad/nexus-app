import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:nx_cards/settings/appearance.dart';
import 'package:nx_db/auth.dart';

Future<void> _logoutAndClearSession(WidgetRef ref) async {
  await ref.read(authProvider.notifier).logout();
  await clearCardsCachedSession();
  ref.invalidate(activeCardsSessionProvider);
  await ref.read(activeCardsSessionProvider.future);
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reviewProgressionSettingsProvider);
    final appearance = ref.watch(appearanceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            key: const Key('app-bar-sign-out-button'),
            tooltip: 'Sign out or change server',
            onPressed: () async {
              await _logoutAndClearSession(ref);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load settings: $error')),
        data: (value) => appearance.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _SettingsForm(
            initial: value,
            initialAppearance: AppAppearance.system,
          ),
          data: (appearance) =>
              _SettingsForm(initial: value, initialAppearance: appearance),
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial, required this.initialAppearance});

  final ReviewProgressionSettings initial;
  final AppAppearance initialAppearance;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late AppAppearance _appearance = widget.initialAppearance;
  late int _historyWindow = widget.initial.historyWindow;
  bool _saving = false;
  bool _syncing = false;
  String? _syncMessage;
  bool _syncFailed = false;

  bool get _valid => _historyWindow >= 1 && _historyWindow <= 10;

  Future<void> _selectAppearance(AppAppearance appearance) async {
    setState(() => _appearance = appearance);
    await ref.read(appearanceProvider.notifier).setAppearance(appearance);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final settings = ReviewProgressionSettings(historyWindow: _historyWindow);
    try {
      await ref.read(reviewProgressionSettingsStoreProvider).save(settings);
      ref.invalidate(reviewProgressionSettingsProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _fullSync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _syncMessage = null;
      _syncFailed = false;
    });
    try {
      final count = await ref.read(cardsFullSyncProvider)();
      if (!mounted) return;
      setState(
        () => _syncMessage = 'Full sync complete. $count cards downloaded.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncFailed = true;
        _syncMessage = 'Full sync failed: $error';
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _logout() async {
    await _logoutAndClearSession(ref);
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
              const DomainSettingsTile(),
              const Divider(),
              const SizedBox(height: 18),
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              Text(
                'Choose how Nx Cards looks on this device.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                child: SegmentedButton<AppAppearance>(
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AppAppearance.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('System', maxLines: 1),
                      ),
                    ),
                    ButtonSegment(
                      value: AppAppearance.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Light', maxLines: 1),
                      ),
                    ),
                    ButtonSegment(
                      value: AppAppearance.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Dark', maxLines: 1),
                      ),
                    ),
                  ],
                  selected: {_appearance},
                  onSelectionChanged: (selection) =>
                      _selectAppearance(selection.single),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 18),
              const Text(
                'Review progression',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              const Text(
                'Saved to your account. Active cards with no attempts are Upcoming. Below 80% is Current; 80% or more is Past. Missing answers count toward the window.',
                style: TextStyle(color: RecallColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              _SettingsCard(
                child: DropdownButtonFormField<int>(
                  initialValue: _historyWindow,
                  decoration: const InputDecoration(
                    labelText: 'Recent answers to consider',
                  ),
                  items: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
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
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 18),
              const Text(
                'Offline library',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              const Text(
                'Upload pending reviews, then download a fresh snapshot of every card from the server.',
                style: TextStyle(color: RecallColors.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonalIcon(
                      key: const Key('full-sync-button'),
                      onPressed: _syncing ? null : _fullSync,
                      icon: _syncing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        _syncing ? 'Synchronizing…' : 'Full sync now',
                      ),
                    ),
                    if (_syncMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _syncMessage!,
                        key: const Key('full-sync-result'),
                        style: TextStyle(
                          color: _syncFailed
                              ? Theme.of(context).colorScheme.error
                              : RecallColors.emerald,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _valid && !_saving ? _save : null,
                child: Text(_saving ? 'Saving…' : 'Save settings'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('sign-out-button'),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out or change server'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}
