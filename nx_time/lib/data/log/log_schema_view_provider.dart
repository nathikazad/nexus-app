import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/data/log/log_schema_provider.dart';
import 'package:nx_time/data/schema/model_type_view_mapper.dart';
import 'package:nx_time/domain/schema/model_type_view.dart';

final logSchemaViewProvider = FutureProvider<ModelTypeView>((ref) async {
  final schema = await ref.watch(logSchemaProvider.future);
  return modelTypeViewFromKgql(schema);
});
