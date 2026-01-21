import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';

class RelationshipFormScreen extends ConsumerStatefulWidget {
  final RelationshipType? initialRelationship;

  const RelationshipFormScreen({
    super.key,
    this.initialRelationship,
  });

  @override
  ConsumerState<RelationshipFormScreen> createState() => _RelationshipFormScreenState();
}

class _RelationshipFormScreenState extends ConsumerState<RelationshipFormScreen> {
  int? _targetModelTypeId;
  String? _targetModelTypeName;
  String _multiplicity = 'many';
  String? _description;
  final TextEditingController _descriptionController = TextEditingController();
  List<RelationAttributeDefinition> _relationAttributeDefinitions = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialRelationship != null) {
      final rel = widget.initialRelationship!;
      _targetModelTypeId = rel.link is int ? rel.link as int : null;
      _targetModelTypeName = rel.link is String ? rel.link as String : null;
      _multiplicity = rel.multiplicity ?? 'many';
      _description = rel.description;
      if (_description != null) {
        _descriptionController.text = _description!;
      }
      // Load relation attribute definitions if editing
      if (rel.relationAttributeDefinitions != null) {
        _relationAttributeDefinitions = rel.relationAttributeDefinitions!;
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _showAddRelationAttributeDialog() {
    final keyController = TextEditingController();
    String valueType = 'string';
    bool required = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Relation Attribute'),
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
                  setState(() {
                    _relationAttributeDefinitions.add(
                      RelationAttributeDefinition(
                        key: keyController.text,
                        valueType: valueType,
                        required: required,
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_targetModelTypeId == null && _targetModelTypeName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target model type')),
      );
      return;
    }

    final link = _targetModelTypeId ?? _targetModelTypeName!;
    final relationship = RelationshipType(
      id: widget.initialRelationship?.id, // Preserve ID when updating
      link: link,
      multiplicity: _multiplicity,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      relationAttributeDefinitions: _relationAttributeDefinitions.isNotEmpty
          ? _relationAttributeDefinitions
          : null,
    );

    Navigator.pop(context, relationship);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialRelationship != null ? 'Edit Relationship' : 'Add Relationship'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Target Model Type field
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Target Model Type: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: _targetModelTypeName != null
                        ? Row(
                            children: [
                              Expanded(
                                child: Text(_targetModelTypeName!),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _targetModelTypeId = null;
                                    _targetModelTypeName = null;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              final result = await context.push('/model-type-selector');
                              if (result != null && result is Map<String, dynamic>) {
                                setState(() {
                                  _targetModelTypeId = result['id'] as int;
                                  _targetModelTypeName = result['name'] as String;
                                });
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Multiplicity dropdown
            DropdownButtonFormField<String>(
              value: _multiplicity,
              decoration: const InputDecoration(
                labelText: 'Multiplicity',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'one', child: Text('One')),
                DropdownMenuItem(value: 'many', child: Text('Many')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _multiplicity = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // Relation Attribute Definitions section
            Row(
              children: [
                const Text(
                  'Relation Attributes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddRelationAttributeDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Display added relation attribute definitions
            if (_relationAttributeDefinitions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No relation attributes added',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._relationAttributeDefinitions.asMap().entries.map((entry) {
                final index = entry.key;
                final attr = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(attr.key),
                    subtitle: Text(
                      'Type: ${attr.valueType} • Required: ${attr.required}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _relationAttributeDefinitions.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

