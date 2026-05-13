import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart' show SetModelTypeRequest, createModelType;

Future<void> submitSetModelTypeRequest(
  ProviderContainer container,
  SetModelTypeRequest req,
) => createModelType(container, req);
