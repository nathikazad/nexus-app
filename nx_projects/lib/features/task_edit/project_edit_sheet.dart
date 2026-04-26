import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/features/task_edit/reference_dialog_shell.dart';

Future<void> showProjectEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required void Function() onSave,
  bool useReferenceDialog = false,
}) {
  if (useReferenceDialog) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x99080A0E),
      barrierDismissible: true,
      builder: (ctx) {
        return ProjectEditForm(
          useReferenceDialog: true,
          sidePanel: false,
          onSidePanelClose: null,
          onSave: onSave,
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return ProjectEditForm(
        useReferenceDialog: false,
        sidePanel: false,
        onSidePanelClose: null,
        onSave: onSave,
      );
    },
  );
}

class ProjectEditForm extends ConsumerStatefulWidget {
  const ProjectEditForm({
    super.key,
    required this.useReferenceDialog,
    this.sidePanel = false,
    this.onSidePanelClose,
    required this.onSave,
  });

  final bool useReferenceDialog;
  final bool sidePanel;
  final VoidCallback? onSidePanelClose;
  final VoidCallback onSave;

  @override
  ConsumerState<ProjectEditForm> createState() => _ProjectEditFormState();
}

class _ProjectEditFormState extends ConsumerState<ProjectEditForm> {
  bool _topLevel = true;
  int? _parentId;
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

  String _scopeHint() {
    return _topLevel
        ? 'A new top-level project shown as its own tree node.'
        : 'A project nested under an existing top-level project.';
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(projectRepositoryProvider);
    if (_topLevel) {
      await repo.addProject(
        Project(
          id: 0,
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
          id: 0,
          name: name,
          color: 0xFF6AA3FF,
          parentId: parent,
        ),
      );
    }
    ref.invalidate(allProjectsAsyncProvider);
    ref.invalidate(projectsListAsyncProvider);
    widget.onSave();
    if (widget.onSidePanelClose != null) {
      widget.onSidePanelClose!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _dismiss() {
    if (widget.onSidePanelClose != null) {
      widget.onSidePanelClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sidePanel) {
      return _buildSidePanel();
    }
    if (widget.useReferenceDialog) {
      return ReferenceDialog(
        title: 'New project',
        onClose: _dismiss,
        primaryLabel: 'Create project',
        cancelLabel: 'Cancel',
        onPrimary: _submit,
        child: _buildProjectFormBody(),
      );
    }
    return _buildSheet();
  }

  Widget _buildSidePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: _buildProjectFormBody(),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: RefModalActions(
            onCancel: _dismiss,
            onPrimary: _submit,
            cancelLabel: 'Cancel',
            primaryLabel: 'Create project',
          ),
        ),
      ],
    );
  }

  Widget _buildProjectFormBody() {
    final roots = ref.watch(projectsListProvider).where((p) => p.parentId == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RefFieldLabel('Scope'),
        const SizedBox(height: 6),
        _refScopeSeg(),
        const SizedBox(height: 4),
        Text(
          _scopeHint(),
          style: const TextStyle(fontSize: 11, color: AppColors.dim, height: 1.4),
        ),
        if (!_topLevel) ...[
          const SizedBox(height: 14),
          const RefFieldLabel('Parent project'),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: _parentId,
            isExpanded: true,
            isDense: true,
            decoration: refFieldDecoration(null),
            dropdownColor: AppColors.panel2,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            items: roots
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _parentId = v),
          ),
        ],
        const SizedBox(height: 14),
        const RefFieldLabel('Name'),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: refFieldDecoration(null, hint: 'e.g. Billing v2'),
        ),
        if (_topLevel) ...[
          const SizedBox(height: 14),
          const RefFieldLabel('Color'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _swatches.map((c) {
              final sel = _color == c;
              return InkWell(
                onTap: () => setState(() => _color = c),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? AppColors.text : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 3)]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 14),
        const RefFieldLabel('Description', suffixOpt: true),
        const SizedBox(height: 6),
        TextField(
          controller: _desc,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: refFieldDecoration(null, hint: 'What this project is about…', isDense: false),
        ),
      ],
    );
  }

  Widget _refScopeSeg() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scopeBtn(
            label: 'Top-level project',
            selected: _topLevel,
            onTap: () => setState(() => _topLevel = true),
          ),
          _scopeBtn(
            label: 'Subproject',
            selected: !_topLevel,
            onTap: () => setState(() => _topLevel = false),
          ),
        ],
      ),
    );
  }

  Widget _scopeBtn({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.panel3 : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.text : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet() {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'New project',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            _buildProjectFormBody(),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            RefModalActions(
              onCancel: _dismiss,
              onPrimary: _submit,
              cancelLabel: 'Cancel',
              primaryLabel: 'Create project',
            ),
          ],
        ),
      ),
    );
  }
}
