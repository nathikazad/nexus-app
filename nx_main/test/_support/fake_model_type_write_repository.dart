import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/model_type_write_repository.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_definition_draft.dart';

class FakeModelTypeWriteRepository implements ModelTypeWriteRepository {
  FakeModelTypeWriteRepository({this.nextId = 1});

  int nextId;
  int callCount = 0;
  int? lastId;
  String? lastName;
  String? lastTypeKind;
  String? lastDescription;
  int? lastParentId;
  List<AttributeDefinitionDraft>? lastAttributes;
  List<RelationDefinitionDraft>? lastRelations;
  int? lastDeletedId;

  @override
  Future<int> setModelType({
    int? id,
    required String name,
    required String typeKind,
    String? description,
    int? parentId,
    required List<AttributeDefinitionDraft> attributeDefinitions,
    required List<RelationDefinitionDraft> relationshipTypes,
  }) async {
    callCount++;
    lastId = id;
    lastName = name;
    lastTypeKind = typeKind;
    lastDescription = description;
    lastParentId = parentId;
    lastAttributes = List<AttributeDefinitionDraft>.from(attributeDefinitions);
    lastRelations = List<RelationDefinitionDraft>.from(relationshipTypes);
    return id ?? nextId++;
  }

  @override
  Future<void> deleteModelType(int id) async {
    lastDeletedId = id;
  }
}
