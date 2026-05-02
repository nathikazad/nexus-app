import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_projects/core/theme/app_theme.dart';

/// Login (user id + backend preset), same flow as
/// [nx_time TimeLoginScreen] / nx_expense ExpenseLoginScreen, dark theme.
class ProjectsLoginScreen extends ConsumerStatefulWidget {
  ProjectsLoginScreen({super.key});

  @override
  ConsumerState<ProjectsLoginScreen> createState() =>
      _ProjectsLoginScreenState();
}

class _ProjectsLoginScreenState extends ConsumerState<ProjectsLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthLoginProfile _selectedProfile = authLoginProfiles.first;
  BackendPreset _selectedPreset = BackendPreset.defaultPreset;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final errorMessage = await ref
        .read(authProvider.notifier)
        .login(
          _selectedProfile.userId,
          _selectedPreset,
          _selectedProfile.personalDomainId,
          _selectedProfile.homeDomainId,
        );

    if (errorMessage == null) {
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: context.colors.crit,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final loading = authState.isLoading;

    final labelStyle = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: context.colors.muted,
      letterSpacing: 1.2,
    );

    InputDecoration fieldDeco(String hint, {Widget? prefix}) {
      return InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: context.colors.dim),
        prefixIcon: prefix,
        filled: true,
        fillColor: context.colors.panel,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.accent, width: 1),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: 48),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.colors.accent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.view_kanban_outlined,
                    color: context.colors.bg,
                    size: 32,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Nexus Projects',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: context.colors.text,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sign in to load your planner from the backend.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('PERSON', style: labelStyle),
                ),
                SizedBox(height: 6),
                DropdownButtonFormField<AuthLoginProfile>(
                  isExpanded: true,
                  initialValue: _selectedProfile,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.text,
                  ),
                  decoration: fieldDeco(
                    'Select person',
                    prefix: Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.person_outline,
                        color: context.colors.muted,
                        size: 20,
                      ),
                    ),
                  ),
                  dropdownColor: context.colors.panel2,
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
                      : (AuthLoginProfile? profile) {
                          if (profile != null) {
                            setState(() => _selectedProfile = profile);
                          }
                        },
                ),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('BACKEND', style: labelStyle),
                ),
                SizedBox(height: 6),
                DropdownButtonFormField<BackendPreset>(
                  isExpanded: true,
                  key: ValueKey<BackendPreset>(_selectedPreset),
                  initialValue: _selectedPreset,
                  decoration: fieldDeco(
                    'Select backend',
                    prefix: Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.dns_outlined,
                        color: context.colors.muted,
                        size: 20,
                      ),
                    ),
                  ),
                  dropdownColor: context.colors.panel2,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.text,
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
                      : (BackendPreset? value) {
                          if (value != null) {
                            setState(() => _selectedPreset = value);
                          }
                        },
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : _handleLogin,
                    child: loading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.bg,
                            ),
                          )
                        : Text(
                            'Log In',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                if (authState.hasError)
                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      'Error: ${authState.error}',
                      style: GoogleFonts.inter(
                        color: context.colors.crit,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
