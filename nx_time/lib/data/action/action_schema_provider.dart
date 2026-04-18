import 'package:nx_db/riverpod.dart';

import 'package:nx_time/data/action/action_attr_keys.dart';

/// Cached [ModelType] for abstract [Action] (from [getKgqlModelType]).
final actionSchemaProvider = modelTypeByNameProvider(kActionModelTypeName);
