import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nx_db/auth.dart';

import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/today/today_view_model.dart';

import 'fake_action_repository.dart';
import 'screenshot_today_snapshot.dart';

/// Logged-in user without hitting the network; fixed [TodaySnapshot] for stable screenshots.
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
      actionRepositoryProvider.overrideWith(
        (ref) => FakeActionRepository(
          initial: buildScreenshotTodaySnapshot().sourceActions,
        ),
      ),
      modelTypeColorsProvider.overrideWith(
        (ref) async => ModelTypeColors.fallback,
      ),
      todaySnapshotProvider.overrideWithValue(
        AsyncData(buildScreenshotTodaySnapshot()),
      ),
    ];
