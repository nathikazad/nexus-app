import 'package:nx_notes/core/version/app_version_info.dart';
import 'package:nx_notes/core/version/app_version_loader_fallback.dart'
    if (dart.library.io) 'package:nx_notes/core/version/app_version_loader_native.dart'
    as implementation;

Future<AppVersionInfo> loadAppVersionInfo() {
  return implementation.loadAppVersionInfo();
}
