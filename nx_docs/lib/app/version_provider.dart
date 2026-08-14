import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/app/version_info.dart';
import 'package:nx_docs/app/version.dart';

final appVersionInfoProvider = FutureProvider<AppVersionInfo>((ref) {
  return loadAppVersionInfo();
});
