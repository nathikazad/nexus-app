import 'package:flutter/material.dart';
import 'package:nexus_voice_assistant/domain/schema/attribute_definition_draft.dart';

class AttributeDefinitionsSection extends StatelessWidget {
  final List<AttributeDefinitionDraft> attributeDefinitions;
  final Function(AttributeDefinitionDraft) onAdd;
  final Function(int, AttributeDefinitionDraft) onUpdate;
  final Function(int) onDelete;

  const AttributeDefinitionsSection({
    super.key,
    required this.attributeDefinitions,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  void _showAttributeDialog(
    BuildContext context, {
    AttributeDefinitionDraft? attribute,
    int? index,
  }) {
    final keyController = TextEditingController(text: attribute?.key ?? '');
    final choicesController = TextEditingController(
      text: ((attribute?.constraints?['enum'] as List?) ?? []).join('\n'),
    );
    String valueType = attribute?.valueType ?? 'string';
    bool required = attribute?.required ?? false;
    final isEditing = attribute != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing
              ? 'Edit Attribute Definition'
              : 'Add Attribute Definition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: valueType,
                  decoration: const InputDecoration(
                    labelText: 'Value Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'string', child: Text('String')),
                    DropdownMenuItem(value: 'enum', child: Text('Enum')),
                    DropdownMenuItem(value: 'number', child: Text('Number')),
                    DropdownMenuItem(value: 'boolean', child: Text('Boolean')),
                    DropdownMenuItem(
                        value: 'datetime', child: Text('DateTime')),
                    DropdownMenuItem(value: 'vector', child: Text('Vector')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        valueType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (valueType == 'enum') ...[
                  TextFormField(
                    controller: choicesController,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Allowed values (one per line)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                CheckboxListTile(
                  title: const Text('Required'),
                  value: required,
                  onChanged: (value) {
                    setDialogState(() {
                      required = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final choices = choicesController.text
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList();
                if (valueType == 'enum' && choices.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Enter at least one allowed value')),
                  );
                  return;
                }
                if (keyController.text.isNotEmpty) {
                  final newAttribute = AttributeDefinitionDraft(
                    id: attribute?.id,
                    key: keyController.text,
                    valueType: valueType,
                    required: required,
                    constraints: {
                      ...?attribute?.constraints,
                      if (valueType == 'enum') 'enum': choices,
                    },
                  );
                  if (isEditing && index != null) {
                    onUpdate(index, newAttribute);
                  } else {
                    onAdd(newAttribute);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleAttributes = attributeDefinitions
        .asMap()
        .entries
        .where((entry) => !entry.value.delete)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Attribute Definitions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAttributeDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (visibleAttributes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No attribute definitions added',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...visibleAttributes.map((entry) {
            final index = entry.key;
            final attr = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(attr.key ?? ''),
                subtitle: Text(
                  'Type: ${attr.valueType} • Required: ${attr.required}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAttributeDialog(
                        context,
                        attribute: attr,
                        index: index,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => onDelete(index),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
