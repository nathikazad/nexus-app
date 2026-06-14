import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_notes/data/essay/essay_schema_provider.dart';
import 'package:nx_notes/data/essay/kgql_essay_repository.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_repository.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';

final essayRepositoryProvider = Provider<EssayRepository>((ref) {
  return KgqlEssayRepository(
    client: ref.watch(graphqlClientProvider),
    loadEssaySchema: () => ref.read(essaySchemaProvider.future),
    loadEssaySnapSchema: () => ref.read(essaySnapSchemaProvider.future),
  );
});

class EssayActiveHeading {
  const EssayActiveHeading({required this.essayId, required this.blockIndex});

  final int essayId;
  final int blockIndex;
}

final essayActiveHeadingNotifier = ValueNotifier<EssayActiveHeading?>(null);

class EssayHeadingScrollRequest {
  const EssayHeadingScrollRequest({
    required this.essayId,
    required this.blockIndex,
    required this.serial,
  });

  final int essayId;
  final int blockIndex;
  final int serial;
}

final essayHeadingScrollRequestNotifier =
    ValueNotifier<EssayHeadingScrollRequest?>(null);

void requestEssayHeadingScroll({
  required int essayId,
  required int blockIndex,
}) {
  final nextSerial = (essayHeadingScrollRequestNotifier.value?.serial ?? 0) + 1;
  essayHeadingScrollRequestNotifier.value = EssayHeadingScrollRequest(
    essayId: essayId,
    blockIndex: blockIndex,
    serial: nextSerial,
  );
}

class EssayLocalCache extends Notifier<Map<int, Essay>> {
  @override
  Map<int, Essay> build() => const <int, Essay>{};

  void put(Essay essay) {
    state = {...state, essay.id: essay};
  }

  void remove(int id) {
    final next = {...state};
    next.remove(id);
    state = next;
  }
}

final essayLocalCacheProvider =
    NotifierProvider<EssayLocalCache, Map<int, Essay>>(EssayLocalCache.new);

final recentEssaysProvider = FutureProvider<List<Essay>>(
  (ref) => ref.watch(essayRepositoryProvider).listRecent(limit: 20),
);

final pinnedEssaysProvider = FutureProvider<List<Essay>>(
  (ref) => ref.watch(essayRepositoryProvider).listPinned(limit: 20),
);

final tagSystemsProvider = FutureProvider<List<TagSystem>>(
  (ref) => ref.watch(essayRepositoryProvider).listTagSystems(),
);

final essayByIdProvider = FutureProvider.family<Essay?, int>((ref, id) {
  final cached = ref.watch(
    essayLocalCacheProvider.select((essays) => essays[id]),
  );
  if (cached != null && cached.hasFullDocument) {
    return cached;
  }
  return ref.watch(essayRepositoryProvider).getById(id);
});

final essaySnapshotsProvider = FutureProvider.family<List<EssaySnap>, int>(
  (ref, id) => ref.watch(essayRepositoryProvider).listSnapshots(id),
);

final essaySearchProvider = FutureProvider.family<List<Essay>, String>(
  (ref, query) => ref.watch(essayRepositoryProvider).search(query),
);

final projectsProvider = FutureProvider<List<LinkedModel>>(
  (ref) => ref.watch(essayRepositoryProvider).listProjects(),
);

final essaysByTagProvider = FutureProvider.family<List<Essay>, EssayTagFilter>(
  (ref, filter) => ref.watch(essayRepositoryProvider).listByTag(filter),
);
