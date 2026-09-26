import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user.dart';
import 'backend_presets.dart';

/// A device-local preference, never proof of authentication.
Future<AuthLoginProfile?> loadLastLoginProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final id =
      prefs.getString(PrefsKeys.lastUserId) ??
      prefs.getString(PrefsKeys.userId);
  return authLoginProfiles.where((profile) => profile.userId == id).firstOrNull;
}

/// Restores the preference before enabling account selection or sign-in.
/// Only AuthController persists it, after a successful login.
mixin RememberedLoginProfile<T extends StatefulWidget> on State<T> {
  AuthLoginProfile? selectedLoginProfile;
  bool restoringLoginProfile = true;

  @override
  void initState() {
    super.initState();
    _restoreLoginProfile();
  }

  Future<void> _restoreLoginProfile() async {
    AuthLoginProfile? profile;
    try {
      profile = await loadLastLoginProfile();
    } catch (_) {
      // An unavailable preference must require a choice, never a default user.
    }
    if (!mounted) return;
    setState(() {
      selectedLoginProfile ??= profile;
      restoringLoginProfile = false;
    });
  }
}
