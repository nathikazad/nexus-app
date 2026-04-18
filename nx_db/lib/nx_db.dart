library nx_db;

// Core — config, GraphQL client, JSON helpers (tests / advanced callers)
export 'src/core/client/graphql_client.dart';
export 'src/core/client/graphql_client_provider.dart';
export 'src/core/config/backend_presets.dart';
export 'src/core/config/cf_access.dart';
export 'src/core/config/graphql_http_config.dart';
export 'src/core/json/json_coercion.dart';
export 'src/core/json/payload_unwrap.dart';

// Auth
export 'src/auth/user.dart';
export 'src/auth/auth_controller.dart';
export 'src/auth/auth_providers.dart';
export 'src/auth/backend_ping.dart';
export 'src/auth/login_page.dart';

// KGQL — models
export 'src/kgql/models/model.dart';
export 'src/kgql/models/model_type.dart';
export 'src/kgql/models/attribute.dart';
export 'src/kgql/models/relation.dart';
export 'src/kgql/models/tag_node.dart';
export 'src/kgql/models/tag_system.dart';

// KGQL — write DTOs (hide request [ModelAttribute] — use prefixed import for set_kgql_models)
export 'src/kgql/requests/set_model_request.dart' hide ModelAttribute;
export 'src/kgql/requests/set_model_type_request.dart';

// KGQL — documents & repositories (for advanced callers / tests)
export 'src/kgql/documents/get_kgql_models.graphql.dart';
export 'src/kgql/documents/set_kgql_models.graphql.dart';
export 'src/kgql/documents/get_kgql_model_type.graphql.dart';
export 'src/kgql/documents/get_kgql_model_type_all.graphql.dart';
export 'src/kgql/documents/set_kgql_model_type.graphql.dart';
export 'src/kgql/documents/get_kgql_aggregate.graphql.dart';
export 'src/kgql/documents/get_current_transcript.graphql.dart';
export 'src/kgql/documents/add_message_to_transcript.graphql.dart';
export 'src/kgql/documents/transcript_message_subscription.graphql.dart';
export 'src/kgql/repositories/models_repository.dart';
export 'src/kgql/repositories/model_types_repository.dart';
export 'src/kgql/repositories/aggregate_repository.dart';

// KGQL — Riverpod
export 'src/kgql/providers/models_providers.dart';
export 'src/kgql/providers/model_types_providers.dart';
export 'src/kgql/providers/relation_picker_providers.dart';

// Transcript feature
export 'src/transcript/transcript.dart';
export 'src/transcript/transcript_providers.dart';
