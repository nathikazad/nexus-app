import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_db/auth.dart';

class CardsLoginScreen extends ConsumerStatefulWidget {
  const CardsLoginScreen({super.key});

  @override
  ConsumerState<CardsLoginScreen> createState() => _CardsLoginScreenState();
}

class _CardsLoginScreenState extends ConsumerState<CardsLoginScreen> {
  AuthLoginProfile _profile = authLoginProfiles.first;
  BackendPreset _preset = BackendPreset.defaultPreset;

  Future<void> _login() async {
    final error = await ref
        .read(authProvider.notifier)
        .login(_profile.userId, _preset);
    if (error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RecallColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'r',
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'recall',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Study what matters, exactly when it matters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RecallColors.muted),
                ),
                const SizedBox(height: 32),
                DropdownButtonFormField<AuthLoginProfile>(
                  initialValue: _profile,
                  decoration: const InputDecoration(labelText: 'Person'),
                  items: [
                    for (final item in authLoginProfiles)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: loading
                      ? null
                      : (value) => setState(() => _profile = value!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<BackendPreset>(
                  initialValue: _preset,
                  decoration: const InputDecoration(labelText: 'Backend'),
                  items: [
                    for (final item in BackendPreset.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: loading
                      ? null
                      : (value) => setState(() => _preset = value!),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: loading ? null : _login,
                  child: loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
