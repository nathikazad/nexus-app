import '../requests/set_model_request.dart';

/// Create payload for `set_kgql_models`.
SetModelRequest setKgqlCreate({
  required String modelType,
  required String name,
  String? description,
  required List<SetModelAttribute> attributes,
}) {
  return SetModelRequest(
    modelType: modelType,
    name: name,
    description: description,
    attributes: attributes,
  );
}

/// Update payload for `set_kgql_models`.
SetModelRequest setKgqlUpdate({
  required int id,
  String? modelType,
  required String name,
  String? description,
  required List<SetModelAttribute> attributes,
}) {
  return SetModelRequest(
    id: id,
    modelType: modelType,
    name: name,
    description: description,
    attributes: attributes,
  );
}

/// Delete payload for `set_kgql_models`.
SetModelRequest setKgqlDelete(int id) =>
    SetModelRequest(id: id, delete: true);
