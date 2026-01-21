import 'package:flutter/material.dart';

class ModelTypeBasicFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String typeKind;
  final Function(String) onTypeKindChanged;
  final int? parentId;
  final String? parentName;
  final VoidCallback onClearParent;
  final VoidCallback onSelectParent;

  const ModelTypeBasicFields({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.typeKind,
    required this.onTypeKindChanged,
    this.parentId,
    this.parentName,
    required this.onClearParent,
    required this.onSelectParent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Name field
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Parent field
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Parent: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: parentName != null
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(parentName!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onClearParent,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: onSelectParent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Type Kind dropdown
        DropdownButtonFormField<String>(
          value: typeKind,
          decoration: const InputDecoration(
            labelText: 'Type Kind',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'abstract', child: Text('Abstract')),
            DropdownMenuItem(value: 'base', child: Text('Base')),
            DropdownMenuItem(value: 'trait', child: Text('Trait')),
          ],
          onChanged: (value) {
            if (value != null) {
              onTypeKindChanged(value);
            }
          },
        ),
        const SizedBox(height: 16),
        // Description field
        TextFormField(
          controller: descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }
}

