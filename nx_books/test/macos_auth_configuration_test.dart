import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mac builds retain the Keychain capability needed for OIDC', () {
    for (final mode in ['DebugProfile', 'Release']) {
      final entitlements = File(
        'macos/Runner/$mode.entitlements',
      ).readAsStringSync();
      expect(entitlements, contains('<key>keychain-access-groups</key>'));
      expect(
        entitlements,
        contains('<key>com.apple.security.network.client</key>'),
      );
    }
    final project = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    // All three Runner configurations need a developer identity: an ad-hoc
    // signature cannot provide the app identity required by secure storage.
    final runnerConfigs = RegExp(
      r'CODE_SIGN_ENTITLEMENTS = Runner/(?:DebugProfile|Release)\.entitlements;'
      r'\s+CODE_SIGN_IDENTITY = "Apple Development";'
      r'\s+DEVELOPMENT_TEAM = \w+;',
    ).allMatches(project);
    expect(runnerConfigs, hasLength(3));
  });
}
