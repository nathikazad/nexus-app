import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';

/// Login page with userId and backend preset dropdown.
///
/// [onLoginSuccess] is called after a successful login with the resolved
/// [BackendUrls] so the consuming app can perform post-login actions
/// (e.g. connecting a WebSocket, starting a background service).
class LoginPage extends ConsumerStatefulWidget {
  final void Function(BackendUrls urls)? onLoginSuccess;

  const LoginPage({super.key, this.onLoginSuccess});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  AuthLoginProfile _selectedProfile = authLoginProfiles.first;

  BackendPreset _selectedPreset = BackendPreset.defaultPreset;

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final errorMessage = await ref.read(authProvider.notifier).login(
            _selectedProfile.userId,
            _selectedPreset,
            _selectedProfile.personalDomainId,
            _selectedProfile.homeDomainId,
          );

      if (errorMessage == null) {
        final urls = resolve(_selectedPreset);
        widget.onLoginSuccess?.call(urls);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);
    final dropdownTextStyle = theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ) ??
        TextStyle(color: theme.colorScheme.onSurface);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nexus Navigator',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                DropdownButtonFormField<AuthLoginProfile>(
                  initialValue: _selectedProfile,
                  style: dropdownTextStyle,
                  iconEnabledColor: theme.colorScheme.onSurfaceVariant,
                  dropdownColor: theme.colorScheme.surface,
                  decoration: const InputDecoration(
                    labelText: 'Person',
                    border: OutlineInputBorder(),
                    helperText: 'Select the fixed user/domain profile',
                  ),
                  items: authLoginProfiles
                      .map(
                        (profile) => DropdownMenuItem<AuthLoginProfile>(
                          value: profile,
                          child: Text(profile.label, style: dropdownTextStyle),
                        ),
                      )
                      .toList(),
                  onChanged: isLoading
                      ? null
                      : (AuthLoginProfile? profile) {
                          if (profile != null) {
                            setState(() => _selectedProfile = profile);
                          }
                        },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BackendPreset>(
                  initialValue: _selectedPreset,
                  style: dropdownTextStyle,
                  iconEnabledColor: theme.colorScheme.onSurfaceVariant,
                  dropdownColor: theme.colorScheme.surface,
                  decoration: const InputDecoration(
                    labelText: 'Backend',
                    border: OutlineInputBorder(),
                    helperText:
                        'GraphQL, socket, and image URLs for this environment',
                  ),
                  items: BackendPreset.values
                      .map(
                        (p) => DropdownMenuItem<BackendPreset>(
                          value: p,
                          child: Text(p.label, style: dropdownTextStyle),
                        ),
                      )
                      .toList(),
                  onChanged: isLoading
                      ? null
                      : (BackendPreset? value) {
                          if (value != null) {
                            setState(() => _selectedPreset = value);
                          }
                        },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
                if (authState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Error: ${authState.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
