import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_db/auth.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

/// Login gate for real PGDB-backed cooking data.
///
/// Mirrors nx_time: auth owns user id + backend preset, then nx_db derives the
/// GraphQL endpoint and `x-user-id` header before recipe providers are allowed
/// to load.
class CookingLoginScreen extends ConsumerStatefulWidget {
  const CookingLoginScreen({super.key});

  @override
  ConsumerState<CookingLoginScreen> createState() => _CookingLoginScreenState();
}

class _CookingLoginScreenState extends ConsumerState<CookingLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthLoginProfile _selectedProfile = authLoginProfiles.first;
  BackendPreset _selectedPreset = BackendPreset.defaultPreset;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final errorMessage = await ref
        .read(authProvider.notifier)
        .login(_selectedProfile.userId, _selectedPreset);

    if (errorMessage == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final loading = authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 52),
                Align(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.orange500,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange500.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      SolarLinearIcons.chefHatMinimalistic,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Nexus Cooking',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.zinc900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to load recipes from PGDB.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.zinc500),
                ),
                const SizedBox(height: 44),
                const _FieldLabel('PERSON'),
                const SizedBox(height: 6),
                DropdownButtonFormField<AuthLoginProfile>(
                  initialValue: _selectedProfile,
                  decoration: _fieldDecoration(
                    'Select person',
                    prefix: const Icon(
                      SolarLinearIcons.userRounded,
                      color: AppColors.zinc400,
                      size: 20,
                    ),
                  ),
                  items: authLoginProfiles
                      .map(
                        (profile) => DropdownMenuItem<AuthLoginProfile>(
                          value: profile,
                          child: Text(profile.label),
                        ),
                      )
                      .toList(),
                  onChanged: loading
                      ? null
                      : (profile) {
                          if (profile != null) {
                            setState(() => _selectedProfile = profile);
                          }
                        },
                ),
                const SizedBox(height: 16),
                const _FieldLabel('BACKEND'),
                const SizedBox(height: 6),
                DropdownButtonFormField<BackendPreset>(
                  initialValue: _selectedPreset,
                  decoration: _fieldDecoration(
                    'Select backend',
                    prefix: const Icon(
                      Icons.dns_outlined,
                      color: AppColors.zinc400,
                      size: 20,
                    ),
                  ),
                  items: BackendPreset.values
                      .map(
                        (p) => DropdownMenuItem<BackendPreset>(
                          value: p,
                          child: Text(p.label),
                        ),
                      )
                      .toList(),
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedPreset = value);
                          }
                        },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Log In',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
                if (authState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      'Error: ${authState.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.zinc400,
        letterSpacing: 1.2,
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint, {Widget? prefix}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: prefix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: prefix,
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 44),
    filled: true,
    fillColor: AppColors.zinc50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.zinc200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.orange500),
    ),
  );
}
