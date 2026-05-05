import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_notes/data/essay/essay_schema_provider.dart';
import 'package:nx_notes/data/essay/kgql_essay_repository.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_repository.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';

final essayRepositoryProvider = Provider<EssayRepository>((ref) {
  final personal = ref.watch(personalDomainIdProvider);
  if (personal == null) {
    throw StateError('personalDomainId required (login)');
  }
  return KgqlEssayRepository(
    client: ref.watch(graphqlClientProvider),
    loadEssaySchema: () => ref.read(essaySchemaProvider.future),
    loadEssaySnapSchema: () => ref.read(essaySnapSchemaProvider.future),
    domainId: personal,
  );
});

final recentEssaysProvider = FutureProvider<List<Essay>>(
  (ref) => ref.watch(essayRepositoryProvider).listRecent(limit: 20),
);

final pinnedEssaysProvider = FutureProvider<List<Essay>>(
  (ref) => ref.watch(essayRepositoryProvider).listPinned(limit: 20),
);

final tagSystemsProvider = FutureProvider<List<TagSystem>>(
  (ref) => ref.watch(essayRepositoryProvider).listTagSystems(),
);

final essayByIdProvider = FutureProvider.family<Essay?, int>(
  (ref, id) => ref.watch(essayRepositoryProvider).getById(id),
);

final essaySnapshotsProvider = FutureProvider.family<List<EssaySnap>, int>(
  (ref, id) => ref.watch(essayRepositoryProvider).listSnapshots(id),
);

final essaySearchProvider = FutureProvider.family<List<Essay>, String>(
  (ref, query) => ref.watch(essayRepositoryProvider).search(query),
);

final essaysByTagProvider = FutureProvider.family<List<Essay>, EssayTagFilter>(
  (ref, filter) => ref.watch(essayRepositoryProvider).listByTag(filter),
);
