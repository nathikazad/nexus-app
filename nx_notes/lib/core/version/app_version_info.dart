const String kAppVersion = '0.1.0';
const String kAppBuildNumber = '1';

final class AppVersionInfo {
  const AppVersionInfo({
    required this.shorebirdAvailable,
    this.patchNumber,
    this.patchReadFailed = false,
  });

  final bool shorebirdAvailable;
  final int? patchNumber;
  final bool patchReadFailed;

  String get releaseLabel => '$kAppVersion ($kAppBuildNumber)';

  String get patchLabel {
    if (!shorebirdAvailable) return 'Shorebird unavailable on this build';
    if (patchReadFailed) return 'Shorebird patch status unavailable';
    final patch = patchNumber;
    return patch == null ? 'Base release (no patch)' : 'Shorebird patch $patch';
  }
}
