import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/today_snapshot.dart';
import '../data/today_repository.dart' show todayRepositoryProvider;

/// Today tab snapshot — uses [todayRepositoryProvider] (fake or KGQL).
final todaySnapshotProvider = FutureProvider<TodaySnapshot>((ref) async {
  final repo = ref.watch(todayRepositoryProvider);
  return repo.loadToday();
});
