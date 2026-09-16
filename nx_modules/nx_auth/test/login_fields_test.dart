import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_auth/nx_auth.dart';

void main() {
  testWidgets('hosted account selection survives changing the backend', (
    tester,
  ) async {
    var preset = BackendPreset.hosted;
    var profile = authLoginProfiles.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AuthLoginFields(
              preset: preset,
              profile: profile,
              loading: false,
              onPresetChanged: (value) => setState(() => preset = value),
              onProfileChanged: (value) => setState(() => profile = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<AuthLoginProfile>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yareni').last);
    await tester.pumpAndSettle();
    expect(profile.userId, '2');
    expect(profile.loginHint, 'yareni');
    await tester.tap(find.byType(DropdownButtonFormField<BackendPreset>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(BackendPreset.piLan.label).last);
    await tester.pumpAndSettle();
    expect(preset, BackendPreset.piLan);
    expect(profile.userId, '2');
  });
}
