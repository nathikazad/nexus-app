import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/core/version/app_version_info.dart';

void main() {
  test('describes a running Shorebird patch', () {
    const info = AppVersionInfo(shorebirdAvailable: true, patchNumber: 7);

    expect(info.releaseLabel, '0.1.0 (3)');
    expect(info.patchLabel, 'Shorebird patch 7');
  });

  test('distinguishes base and unavailable builds', () {
    expect(
      const AppVersionInfo(shorebirdAvailable: true).patchLabel,
      'Base release (no patch)',
    );
    expect(
      const AppVersionInfo(shorebirdAvailable: false).patchLabel,
      'Shorebird unavailable on this build',
    );
  });
}
