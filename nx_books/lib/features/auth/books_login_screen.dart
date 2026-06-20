import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/core/theme/app_theme.dart';
import 'package:nx_db/auth.dart';

class BooksLoginScreen extends ConsumerStatefulWidget {
  const BooksLoginScreen({super.key});

  @override
  ConsumerState<BooksLoginScreen> createState() => _BooksLoginScreenState();
}

class _BooksLoginScreenState extends ConsumerState<BooksLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthLoginProfile _selectedProfile = authLoginProfiles.first;
  BackendPreset _selectedPreset = BackendPreset.defaultPreset;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await ref
        .read(authProvider.notifier)
        .login(_selectedProfile.userId, _selectedPreset);
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: AppColors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final loading = auth.isLoading;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Align(
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.text,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'B',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Nexus Books',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to organize your reading queue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                    const SizedBox(height: 36),
                    const _LoginLabel('PERSON'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<AuthLoginProfile>(
                      isExpanded: true,
                      initialValue: _selectedProfile,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      items: [
                        for (final profile in authLoginProfiles)
                          DropdownMenuItem<AuthLoginProfile>(
                            value: profile,
                            child: Text(profile.label),
                          ),
                      ],
                      onChanged: loading
                          ? null
                          : (profile) {
                              if (profile != null) {
                                setState(() => _selectedProfile = profile);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    const _LoginLabel('BACKEND'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<BackendPreset>(
                      isExpanded: true,
                      initialValue: _selectedPreset,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.dns_outlined, size: 20),
                      ),
                      items: [
                        for (final preset in BackendPreset.values)
                          DropdownMenuItem<BackendPreset>(
                            value: preset,
                            child: Text(preset.label),
                          ),
                      ],
                      onChanged: loading
                          ? null
                          : (preset) {
                              if (preset != null) {
                                setState(() => _selectedPreset = preset);
                              }
                            },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: loading ? null : _login,
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Log In'),
                    ),
                    if (auth.hasError) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${auth.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginLabel extends StatelessWidget {
  const _LoginLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.faint,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
