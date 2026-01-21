import 'package:flutter/material.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';

class AttributeDefinitionsSection extends StatelessWidget {
  final List<AttributeDefinition> attributeDefinitions;
  final Function(AttributeDefinition) onAdd;
  final Function(int, AttributeDefinition) onUpdate;
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
    AttributeDefinition? attribute,
    int? index,
  }) {
    final keyController = TextEditingController(text: attribute?.key ?? '');
    String valueType = attribute?.valueType ?? 'string';
    bool required = attribute?.required ?? false;
    final isEditing = attribute != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Attribute Definition' : 'Add Attribute Definition'),
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
                  value: valueType,
                  decoration: const InputDecoration(
                    labelText: 'Value Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'string', child: Text('String')),
                    DropdownMenuItem(value: 'number', child: Text('Number')),
                    DropdownMenuItem(value: 'boolean', child: Text('Boolean')),
                    DropdownMenuItem(value: 'datetime', child: Text('DateTime')),
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
                if (keyController.text.isNotEmpty) {
                  final updatedAttribute = AttributeDefinition(
                    id: attribute?.id, // Preserve ID when updating
                    key: keyController.text,
                    valueType: valueType,
                    required: required,
                  );
                  
                  if (isEditing && index != null) {
                    onUpdate(index, updatedAttribute);
                  } else {
                    onAdd(updatedAttribute);
                  }
                  
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
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
        // Display added attribute definitions
        if (attributeDefinitions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No attribute definitions added',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...attributeDefinitions.asMap().entries
              .where((entry) => !entry.value.delete) // Filter out deleted items
              .map((entry) {
            final index = entry.key;
            final attr = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(attr.key ?? ''),
                subtitle: Text(
                  'Type: ${attr.valueType ?? 'unknown'} • Required: ${attr.required}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _showAttributeDialog(
                          context,
                          attribute: attr,
                          index: index,
                        );
                      },
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

