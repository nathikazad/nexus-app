import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../app_theme.dart';
import '../../layout.dart';

/// Login (user id + backend preset), same fields as [LoginPage] / nx_expense [ExpenseLoginScreen].
class TimeLoginScreen extends ConsumerStatefulWidget {
  const TimeLoginScreen({super.key});

  @override
  ConsumerState<TimeLoginScreen> createState() => _TimeLoginScreenState();
}

class _TimeLoginScreenState extends ConsumerState<TimeLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  BackendPreset _selectedPreset = BackendPreset.defaultPreset;

  @override
  void initState() {
    super.initState();
    _userIdController.text = GraphQLConfig.defaultUserId;
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = _userIdController.text.trim();

    final errorMessage =
        await ref.read(authProvider.notifier).login(userId, _selectedPreset);

    if (errorMessage == null) {
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.red600,
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
      color: AppColors.slate500,
      letterSpacing: 1.2,
    );

    InputDecoration fieldDeco(String hint, {Widget? prefix}) {
      return InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        filled: true,
        fillColor: AppColors.slate50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: RefLayout.px5),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 48),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    SolarLinearIcons.alarm,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Nexus Time',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to load your day from the backend.',
                  style:
                      GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('USER ID', style: labelStyle),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _userIdController,
                  enabled: !loading,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: fieldDeco(
                    'Enter user ID',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.person_outline,
                        color: AppColors.slate400,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'User ID is required' : null,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('BACKEND', style: labelStyle),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<BackendPreset>(
                  initialValue: _selectedPreset,
                  decoration: fieldDeco(
                    'Select backend',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.dns_outlined,
                        color: AppColors.slate400,
                        size: 20,
                      ),
                    ),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.slate900,
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : _handleLogin,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
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
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Error: ${authState.error}',
                      style: GoogleFonts.inter(
                        color: AppColors.red600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
