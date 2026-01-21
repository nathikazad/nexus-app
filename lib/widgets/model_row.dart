import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexus_voice_assistant/models/Model.dart';

class ModelRow extends StatelessWidget {
  final Model model;
  final VoidCallback onTap;

  const ModelRow({
    super.key,
    required this.model,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = model.name;
    final description = model.description;
    final createdAt = model.createdAt;
    final updatedAt = model.updatedAt;

    String? formatDate(String? dateStr) {
      if (dateStr == null) return null;
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        return dateStr;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null && description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  description.length > 100 ? '${description.substring(0, 100)}...' : description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (updatedAt != null || createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (updatedAt != null)
                      Text(
                        'Updated: ${formatDate(updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (updatedAt != null && createdAt != null)
                      const Text(' • '),
                    if (createdAt != null)
                      Text(
                        'Created: ${formatDate(createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

