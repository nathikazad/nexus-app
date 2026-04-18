import 'package:flutter/material.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import '../../theme/app_colors.dart';

/// Pick backlog tasks to pin to today (`view-task-picker.html`).
class TaskPickerPage extends StatefulWidget {
  const TaskPickerPage({super.key});

  @override
  State<TaskPickerPage> createState() => _TaskPickerPageState();
}

class _PickerTask {
  const _PickerTask({
    required this.title,
    required this.subtitle,
    required this.metaRight,
    this.pinned = false,
    this.pinnedYesterday = false,
  });

  final String title;
  final String subtitle;
  final String metaRight;
  final bool pinned;
  final bool pinnedYesterday;
}

class _TaskPickerPageState extends State<TaskPickerPage> {
  final Set<int> _selected = {0, 1, 3};

  static const _leftOver = [
    _PickerTask(
      title: 'Sync with design team',
      subtitle: 'Platform › UI',
      metaRight: 'pinned yest.',
      pinnedYesterday: true,
    ),
    _PickerTask(
      title: 'Pay internet bill',
      subtitle: 'Home › Admin',
      metaRight: 'pinned yest.',
      pinnedYesterday: true,
    ),
  ];

  static const _work = [
    _PickerTask(
      title: 'Update API docs',
      subtitle: 'Platform › API',
      metaRight: '1w ago',
    ),
    _PickerTask(
      title: 'Draft weekly newsletter',
      subtitle: 'Content › Newsletter',
      metaRight: '2d ago',
      pinned: true,
    ),
  ];

  int get _selectedCount => _selected.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                    color: AppColors.slate600,
                  ),
                  const Expanded(
                    child: Text(
                      'Pick tasks',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  const Text(
                    '23 left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _FilterPill(label: 'All', selected: true, onTap: () {}),
                  _FilterPill(label: 'Yesterday (2)', selected: false, onTap: () {}),
                  _FilterPill(label: 'Work (12)', selected: false, onTap: () {}),
                  _FilterPill(label: 'Personal (5)', selected: false, onTap: () {}),
                  _FilterPill(label: 'Home (4)', selected: false, onTap: () {}),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                children: [
                  _SectionHeader(
                    title: 'Left over from yesterday',
                    dotAccent: true,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_leftOver.length, (i) {
                    final t = _leftOver[i];
                    return _PickerRow(
                      task: t,
                      selected: _selected.contains(i),
                      onTap: () => setState(() {
                        if (_selected.contains(i)) {
                          _selected.remove(i);
                        } else {
                          _selected.add(i);
                        }
                      }),
                    );
                  }),
                  const SizedBox(height: 24),
                  const Text(
                    'WORK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                      color: AppColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_work.length, (j) {
                    final i = j + _leftOver.length;
                    final t = _work[j];
                    return _PickerRow(
                      task: t,
                      selected: _selected.contains(i),
                      onTap: () => setState(() {
                        if (_selected.contains(i)) {
                          _selected.remove(i);
                        } else {
                          _selected.add(i);
                        }
                      }),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        color: Colors.white.withValues(alpha: 0.92),
        elevation: 0,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.slate100)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedCount selected',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                    const Text(
                      '4 already pinned to today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.slate900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.dotAccent = false});

  final String title;
  final bool dotAccent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (dotAccent) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.slate900,
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.slate900 : AppColors.slate100,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.slate600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final _PickerTask task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: selected
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.25),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          SolarLinearIcons.checkRead,
                          size: 14,
                          color: Colors.white,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.slate300),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              if (task.metaRight.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: task.pinnedYesterday
                        ? AppColors.accentLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.metaRight,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: task.pinnedYesterday
                          ? AppColors.accent
                          : AppColors.slate400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
