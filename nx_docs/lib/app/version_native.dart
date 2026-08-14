import 'package:nx_docs/app/version_info.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

Future<AppVersionInfo> loadAppVersionInfo() async {
  final updater = ShorebirdUpdater();
  if (!updater.isAvailable) {
    return const AppVersionInfo(shorebirdAvailable: false);
  }

  try {
    final patch = await updater.readCurrentPatch();
    return AppVersionInfo(shorebirdAvailable: true, patchNumber: patch?.number);
  } on ReadPatchException {
    return const AppVersionInfo(
      shorebirdAvailable: true,
      patchReadFailed: true,
    );
  }
}
