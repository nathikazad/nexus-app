import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';

Future<void> showProjectEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required void Function() onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _ProjectEditBody(onSave: onSave);
    },
  );
}

class _ProjectEditBody extends ConsumerStatefulWidget {
  const _ProjectEditBody({required this.onSave});

  final VoidCallback onSave;

  @override
  ConsumerState<_ProjectEditBody> createState() => _ProjectEditBodyState();
}

class _ProjectEditBodyState extends ConsumerState<_ProjectEditBody> {
  bool _topLevel = true;
  String? _parentId;
  late TextEditingController _name;
  late TextEditingController _desc;
  int _color = 0xFF6AA3FF;

  static const _swatches = <int>[
    0xFF6AA3FF,
    0xFFF59E0B,
    0xFFC084FC,
    0xFF4ADE80,
    0xFFF87171,
    0xFF94A3B8,
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _desc = TextEditingController();
    final roots = ref.read(projectsListProvider).where((p) => p.parentId == null).toList();
    _parentId = roots.isNotEmpty ? roots.first.id : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(projectRepositoryProvider);
    if (_topLevel) {
      await repo.addProject(
        Project(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          color: _color,
          description: _desc.text,
        ),
      );
    } else {
      final parent = _parentId;
      if (parent == null) return;
      await repo.addSubProject(
        parent,
        Project(
          id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          color: 0xFF6AA3FF,
          parentId: parent,
        ),
      );
    }
    widget.onSave();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final roots = ref.watch(projectsListProvider).where((p) => p.parentId == null).toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New project',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Top-level')),
                ButtonSegment(value: false, label: Text('Subproject')),
              ],
              selected: {_topLevel},
              onSelectionChanged: (s) => setState(() => _topLevel = s.first),
            ),
            if (!_topLevel) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _parentId,
                decoration: const InputDecoration(
                  labelText: 'Parent project',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: AppColors.muted),
                ),
                dropdownColor: AppColors.panel2,
                style: const TextStyle(color: AppColors.text),
                items: roots
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                    .toList(),
                onChanged: (v) => setState(() => _parentId = v),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: AppColors.muted),
              ),
            ),
            if (_topLevel) ...[
              const SizedBox(height: 12),
              const Text('COLOR', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _swatches.map((c) {
                  return InkWell(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? AppColors.text : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: _color == c
                            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 4)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
