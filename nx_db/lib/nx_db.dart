library nx_db;

// Core — config, GraphQL client
export 'src/core/client/graphql_client.dart';
export 'src/core/client/graphql_client_provider.dart';
export 'src/core/config/backend_presets.dart';
export 'src/core/config/cf_access.dart';
export 'src/core/config/graphql_http_config.dart';

// Auth
export 'src/auth/user.dart';
export 'src/auth/auth_controller.dart';
export 'src/auth/auth_providers.dart';
export 'src/auth/backend_ping.dart';

// KGQL — models
export 'src/kgql/models/model.dart';
export 'src/kgql/models/model_type.dart';
export 'src/kgql/models/attribute.dart';
export 'src/kgql/models/relation.dart';
export 'src/kgql/models/tag_node.dart';
export 'src/kgql/models/tag_system.dart';

// KGQL — write DTOs
export 'src/kgql/requests/set_model_request.dart';
export 'src/kgql/requests/set_model_type_request.dart';

// KGQL — helpers
export 'src/kgql/helpers/struct_builder.dart';
export 'src/kgql/helpers/set_request_helpers.dart';
export 'src/kgql/helpers/attr_accessors.dart';

// KGQL — repositories
export 'src/kgql/repositories/models_repository.dart';
export 'src/kgql/repositories/model_types_repository.dart';
export 'src/kgql/repositories/aggregate_repository.dart';

// KGQL — Riverpod
export 'src/kgql/providers/models_providers.dart';
export 'src/kgql/providers/model_types_providers.dart';
export 'src/kgql/providers/relation_picker_providers.dart';

// Transcript feature
export 'src/transcript/transcript.dart';
export 'src/transcript/transcript_repository.dart';
export 'src/transcript/transcript_providers.dart';

// Goals (app schema orchestrators)
export 'goals.dart';
