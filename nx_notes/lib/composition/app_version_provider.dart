import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/core/version/app_version_info.dart';
import 'package:nx_notes/core/version/app_version_loader.dart';

final appVersionInfoProvider = FutureProvider<AppVersionInfo>((ref) {
  return loadAppVersionInfo();
});
