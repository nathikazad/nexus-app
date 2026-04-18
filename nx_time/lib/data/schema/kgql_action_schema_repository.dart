import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import 'package:nx_time/data/action/action_schema_provider.dart';

/// Thin wrapper: cached Action root [ModelType] from KGQL.
class KgqlActionSchemaRepository {
  KgqlActionSchemaRepository(this._ref);

  final Ref _ref;

  Future<ModelType> getActionRoot() =>
      _ref.read(actionSchemaProvider.future);
}
