import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/app/theme.dart';

class DocsLoginPage extends ConsumerStatefulWidget {
  const DocsLoginPage({super.key});

  @override
  ConsumerState<DocsLoginPage> createState() => _DocsLoginPageState();
}

class _DocsLoginPageState extends ConsumerState<DocsLoginPage> {
  final _formKey = GlobalKey<FormState>();
  AuthLoginProfile _selectedProfile = authLoginProfiles.first;
  BackendPreset _selectedPreset = BackendPreset.defaultPreset;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await ref
        .read(authProvider.notifier)
        .login(
          _selectedPreset.requiresOidc ? '' : _selectedProfile.userId,
          _selectedPreset,
          profile: _selectedProfile,
        );
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
      backgroundColor: AppColors.bg,
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
                          color: AppColors.floating,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'N',
                          style: TextStyle(
                            color: AppColors.onFloating,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Nx Docs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to load documents from your personal domain.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                    const SizedBox(height: 36),
                    AuthLoginFields(
                      preset: _selectedPreset,
                      profile: _selectedProfile,
                      loading: loading,
                      onPresetChanged: (value) =>
                          setState(() => _selectedPreset = value),
                      onProfileChanged: (value) =>
                          setState(() => _selectedProfile = value),
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
                          : Text(
                              _selectedPreset.requiresOidc
                                  ? 'Continue to sign in'
                                  : 'Log In',
                            ),
                    ),
                    if (auth.hasError) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${auth.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.red, fontSize: 13),
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
