import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/widgets/attribute_definitions_section.dart';

void main() {
  testWidgets('enum editor saves choices in definition metadata', (tester) async {
    AttributeDefinitionDraft? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      AttributeDefinitionsSection(attributeDefinitions: const [],
        onAdd: (value) => saved = value, onUpdate: (_, value) {}, onDelete: (_) {}),
    )));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'type');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enum').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Yoga\nPilates\nYoga');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved?.valueType, 'enum');
    expect(saved?.constraints?['enum'], ['Yoga', 'Pilates']);
  });
}
