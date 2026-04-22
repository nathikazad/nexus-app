// Not part of the public API; may break in any release.
//
// Escape hatch for tests and tooling that need raw GraphQL document strings or
// JSON helpers.

library;

export 'src/core/json/json_coercion.dart';
export 'src/core/json/payload_unwrap.dart';
export 'src/kgql/documents/get_kgql_models.graphql.dart';
export 'src/kgql/documents/set_kgql_models.graphql.dart';
export 'src/kgql/documents/get_kgql_model_type.graphql.dart';
export 'src/kgql/documents/get_kgql_model_type_all.graphql.dart';
export 'src/kgql/documents/set_kgql_model_type.graphql.dart';
export 'src/kgql/documents/get_kgql_aggregate.graphql.dart';
export 'src/goals/documents/get_action_goals_week.graphql.dart';
export 'src/goals/documents/get_action_goals_trend.graphql.dart';
export 'src/goals/documents/get_expense_goals_month.graphql.dart';
export 'src/kgql/documents/get_current_transcript.graphql.dart';
export 'src/kgql/documents/add_message_to_transcript.graphql.dart';
export 'src/kgql/documents/transcript_message_subscription.graphql.dart';
