import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/data/schema/kgql_model_type_repository.dart';
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_definition_draft.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/model_type_form_view_model.dart';

import '../../_support/fake_model_type_write_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelTypeFormController', () {
    test('loadModelTypeData runs only once', () {
      final container = ProviderContainer(
        overrides: [
          modelTypeWriteRepositoryProvider.overrideWithValue(
            FakeModelTypeWriteRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(modelTypeFormControllerProvider(null).notifier);
      notifier.loadModelTypeData(
        const SchemaModelType(id: 1, name: 'First', description: 'A'),
      );
      expect(
        container.read(modelTypeFormControllerProvider(null)).nameController.text,
        'First',
      );

      notifier.loadModelTypeData(
        const SchemaModelType(id: 1, name: 'Second', description: 'B'),
      );
      expect(
        container.read(modelTypeFormControllerProvider(null)).nameController.text,
        'First',
      );
    });

    test('removeAttributeDefinition marks delete when id present', () {
      final container = ProviderContainer(
        overrides: [
          modelTypeWriteRepositoryProvider.overrideWithValue(
            FakeModelTypeWriteRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(modelTypeFormControllerProvider(null).notifier);
      notifier.addAttributeDefinition(
        const AttributeDefinitionDraft(
          id: 7,
          key: 'k',
          valueType: 'string',
        ),
      );
      notifier.removeAttributeDefinition(0);
      final attrs =
          container.read(modelTypeFormControllerProvider(null)).attributeDefinitions;
      expect(attrs.length, 1);
      expect(attrs.single.delete, true);
      expect(attrs.single.id, 7);
    });

    test('removeAttributeDefinition removes row when no id', () {
      final container = ProviderContainer(
        overrides: [
          modelTypeWriteRepositoryProvider.overrideWithValue(
            FakeModelTypeWriteRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(modelTypeFormControllerProvider(null).notifier);
      notifier.addAttributeDefinition(
        const AttributeDefinitionDraft(key: 'k', valueType: 'string'),
      );
      notifier.removeAttributeDefinition(0);
      expect(
        container.read(modelTypeFormControllerProvider(null)).attributeDefinitions,
        isEmpty,
      );
    });

    test('removeRelationship marks delete when id present', () {
      final container = ProviderContainer(
        overrides: [
          modelTypeWriteRepositoryProvider.overrideWithValue(
            FakeModelTypeWriteRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(modelTypeFormControllerProvider(null).notifier);
      notifier.addRelationship(
        const RelationDefinitionDraft(id: 3, link: 'Company'),
      );
      notifier.removeRelationship(0);
      final rels =
          container.read(modelTypeFormControllerProvider(null)).relationshipTypes;
      expect(rels.length, 1);
      expect(rels.single.delete, true);
      expect(rels.single.id, 3);
    });
  });
}
