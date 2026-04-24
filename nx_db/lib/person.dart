/// Person (entity, KGQL repository, Riverpod) — current user’s profile row.
/// Layout: `models/domain/person` + `models/data/person` (mirrors app `lib/domain` / `lib/data`).
library;

export 'src/models/domain/person/person.dart';
export 'src/models/domain/person/person_repository.dart';
export 'src/models/data/person/person_attr_keys.dart';
export 'src/models/data/person/person_mapper.dart';
export 'src/models/data/person/kgql_person_repository.dart';
export 'src/models/data/person/person_providers.dart';
