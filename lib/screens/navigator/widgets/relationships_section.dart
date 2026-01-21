import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/models/ModelType.dart';
import 'package:nexus_voice_assistant/providers/model_types_provider.dart';

import 'package:nexus_voice_assistant/screens/navigator/relationship_form_screen.dart';

class RelationshipsSection extends ConsumerWidget {
  final List<RelationshipType> relationshipTypes;
  final Function(RelationshipType) onAdd;
  final Function(int, RelationshipType) onUpdate;
  final Function(int) onDelete;

  const RelationshipsSection({
    super.key,
    required this.relationshipTypes,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  String? _findModelTypeName(List<ModelType> modelTypes, int id) {
    ModelType? findInList(List<ModelType> types) {
      for (var type in types) {
        if (type.id == id) return type;
        if (type.children != null) {
          final found = findInList(type.children!);
          if (found != null) return found;
        }
        if (type.traits != null) {
          final found = findInList(type.traits!);
          if (found != null) return found;
        }
      }
      return null;
    }
    
    final found = findInList(modelTypes);
    return found?.name;
  }

  Widget _buildRelationshipCard(
    BuildContext context,
    RelationshipType rel,
    int index,
    String targetName,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('To: $targetName'),
        subtitle: Text(
          'Multiplicity: ${rel.multiplicity ?? 'many'}${rel.description != null ? ' • ${rel.description}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push<RelationshipType>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RelationshipFormScreen(
                      initialRelationship: rel,
                    ),
                  ),
                );
                if (result != null) {
                  onUpdate(index, result);
                }
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
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Text(
        'No relationships added',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildRelationshipsList(
    BuildContext context,
    List<ModelType> modelTypes,
  ) {
    final visibleRelationships = relationshipTypes
        .asMap()
        .entries
        .where((entry) => !entry.value.delete)
        .toList();
    
    if (visibleRelationships.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: visibleRelationships.map((entry) {
        final index = entry.key;
        final rel = entry.value;
        final targetName = rel.link is int 
            ? _findModelTypeName(modelTypes, rel.link as int) ?? 'Unknown (ID: ${rel.link})'
            : rel.link is String 
                ? rel.link as String 
                : 'Unknown';
        return _buildRelationshipCard(context, rel, index, targetName);
      }).toList(),
    );
  }

  Widget _buildRelationshipsListLoading() {
    final visibleRelationships = relationshipTypes
        .asMap()
        .entries
        .where((entry) => !entry.value.delete)
        .toList();
    
    if (visibleRelationships.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: visibleRelationships.map((entry) {
        final index = entry.key;
        final rel = entry.value;
        final targetName = rel.link is int 
            ? 'ID: ${rel.link}'
            : rel.link is String 
                ? rel.link as String 
                : 'Unknown';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('To: $targetName'),
            subtitle: Text(
              'Multiplicity: ${rel.multiplicity ?? 'many'}${rel.description != null ? ' • ${rel.description}' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    // Navigation handled in parent context
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
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelTypesAsync = ref.watch(modelTypesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Row(
          children: [
            const Text(
              'Relationships',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push<RelationshipType>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RelationshipFormScreen(),
                  ),
                );
                if (result != null) {
                  onAdd(result);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Display added relationships with Consumer logic
        modelTypesAsync.when(
          data: (modelTypes) => _buildRelationshipsList(context, modelTypes),
          loading: () => _buildRelationshipsListLoading(),
          error: (error, stack) => _buildEmptyState(),
        ),
      ],
    );
  }
}

