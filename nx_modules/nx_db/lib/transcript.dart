/// Transcript (entity, KGQL repository, Riverpod) — current user’s conversation.
/// Layout: `models/domain/transcript` + `models/data/transcript` (mirrors app `lib/domain` / `lib/data`).
library;

export 'src/models/domain/transcript/transcript.dart';
export 'src/models/domain/transcript/transcript_repository.dart';
export 'src/models/data/transcript/transcript_attr_keys.dart';
export 'src/models/data/transcript/transcript_mapper.dart';
export 'src/models/data/transcript/kgql_transcript_repository.dart';
export 'src/models/data/transcript/transcript_providers.dart';
