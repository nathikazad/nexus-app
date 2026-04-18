/// KGQL models, repositories, and helpers — no Riverpod.
library;

export 'src/kgql/models/model.dart';
export 'src/kgql/models/model_type.dart';
export 'src/kgql/models/attribute.dart';
export 'src/kgql/models/relation.dart';
export 'src/kgql/models/tag_node.dart';
export 'src/kgql/models/tag_system.dart';
export 'src/kgql/requests/set_model_request.dart';
export 'src/kgql/requests/set_model_type_request.dart';
export 'src/kgql/repositories/models_repository.dart';
export 'src/kgql/repositories/model_types_repository.dart';
export 'src/kgql/repositories/aggregate_repository.dart';
export 'src/kgql/helpers/struct_builder.dart';
export 'src/kgql/helpers/set_request_helpers.dart';
export 'src/kgql/helpers/attr_accessors.dart';
export 'src/core/client/graphql_client.dart';
