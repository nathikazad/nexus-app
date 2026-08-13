/// Scheduling and review-progression policy.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/scheduling/card_scheduler.dart';
import 'package:nx_cards/scheduling/clock.dart';

export 'card_scheduler.dart';
export 'clock.dart';
export 'review_progression.dart';
export 'review_progression_service.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final cardSchedulerProvider = Provider<CardScheduler>((ref) {
  return FsrsCardScheduler();
});
