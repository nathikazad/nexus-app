import 'package:nx_docs/app/version_info.dart';
import 'package:nx_docs/app/version_fallback.dart'
    if (dart.library.io) 'package:nx_docs/app/version_native.dart'
    as implementation;

Future<AppVersionInfo> loadAppVersionInfo() {
  return implementation.loadAppVersionInfo();
}
