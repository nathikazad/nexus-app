import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/schema/relation_definition_draft.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/relationship_form_page.dart';

void main() {
  testWidgets(
      'editing a self relation preserves both identities and changes its count',
      (tester) async {
    RelationDefinitionDraft? saved;
    const initial = RelationDefinitionDraft(
        id: 7,
        link: 'Task',
        relationName: 'hierarchy',
        definingModelTypeId: 12,
        endpoints: {
          'parent': RelationEndpointDraft(type: 'Task', count: 'one'),
          'children': RelationEndpointDraft(type: 'Task', count: 'many'),
        });
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async {
                          saved = await Navigator.of(context)
                              .push<RelationDefinitionDraft>(MaterialPageRoute(
                                  builder: (_) => const RelationshipFormPage(
                                      modelTypeName: 'Task',
                                      initialRelationship: initial)));
                        },
                        child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Role name'), findsNWidgets(2));
    await tester
        .ensureVisible(find.byType(DropdownButtonFormField<String>).last);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zero or one').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved!.id, 7);
    expect(saved!.definingModelTypeId, 12);
    expect(saved!.relationName, 'hierarchy');
    expect(saved!.endpoints.keys, ['parent', 'children']);
    expect(saved!.endpoints['children']!.count, 'one');
  });
}
