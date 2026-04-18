import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nx_db/nx_db.dart';

import 'package:nx_time/data/today_repository.dart';

import 'screenshot_today_repository.dart';

/// Logged-in user without hitting the network; stub [TodayRepository] for stable screenshots.
class ScreenshotAuthController extends AuthController {
  ScreenshotAuthController()
      : super(initialDelay: Duration.zero, skipBackendPing: true);

  @override
  Future<User?> build() async {
    return User(userId: '1', preset: BackendPreset.laptop);
  }
}

List<Override> get screenshotAuthOverrides => [
      authProvider.overrideWith(() => ScreenshotAuthController()),
      todayRepositoryProvider.overrideWith(
        (ref) => ScreenshotStubTodayRepository(),
      ),
    ];
