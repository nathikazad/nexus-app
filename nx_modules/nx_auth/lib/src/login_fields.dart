import 'package:flutter/material.dart';

import 'backend_presets.dart';
import 'user.dart';

/// Shared backend and account choices. Hosted choices are login hints only;
/// the verified server identity remains the source of authorization.
class AuthLoginFields extends StatelessWidget {
  const AuthLoginFields({
    super.key,
    required this.preset,
    required this.profile,
    required this.loading,
    required this.onPresetChanged,
    required this.onProfileChanged,
  });

  final BackendPreset preset;
  final AuthLoginProfile profile;
  final bool loading;
  final ValueChanged<BackendPreset> onPresetChanged;
  final ValueChanged<AuthLoginProfile> onProfileChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DropdownButtonFormField<BackendPreset>(
        initialValue: preset,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Backend'),
        items: [
          for (final item in BackendPreset.values)
            DropdownMenuItem(value: item, child: Text(item.label)),
        ],
        onChanged: loading
            ? null
            : (value) {
                if (value != null) onPresetChanged(value);
              },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<AuthLoginProfile>(
        initialValue: profile,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Person'),
        items: [
          for (final item in authLoginProfiles)
            DropdownMenuItem(value: item, child: Text(item.label)),
        ],
        onChanged: loading
            ? null
            : (value) {
                if (value != null) onProfileChanged(value);
              },
      ),
    ],
  );
}
