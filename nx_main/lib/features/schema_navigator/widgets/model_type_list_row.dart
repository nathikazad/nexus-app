import 'package:flutter/material.dart';
import 'package:nexus_voice_assistant/domain/schema/schema_model_type.dart';

class ModelTypeListRow extends StatelessWidget {
  final SchemaModelType modelType;
  final VoidCallback? onTap;
  final VoidCallback onSettingsTap;
  final bool showExpandButton;
  final bool isExpanded;
  final VoidCallback? onExpandTap;
  final bool showSettingsButton;

  const ModelTypeListRow({
    super.key,
    required this.modelType,
    this.onTap,
    required this.onSettingsTap,
    this.showExpandButton = false,
    this.isExpanded = false,
    this.onExpandTap,
    this.showSettingsButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final name = modelType.name;
    final description = modelType.description;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: showExpandButton
            ? IconButton(
                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                onPressed: onExpandTap,
              )
            : null,
        title: Text(name),
        subtitle: description != null && description.isNotEmpty
            ? Text(description)
            : null,
        trailing: showSettingsButton
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: onSettingsTap,
            ),
          ],
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

