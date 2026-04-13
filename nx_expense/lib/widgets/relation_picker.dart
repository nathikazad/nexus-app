import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../util/expense_schema.dart';
import '../providers/expense_providers.dart';
import '../layout.dart';

/// Result of the relation picker: link to existing model IDs, or create a new related model.
sealed class RelationPickResult {
  const RelationPickResult();
}

/// Selected existing related models (empty list = cleared / "None").
class RelationPickLink extends RelationPickResult {
  const RelationPickLink(this.ids);

  final List<int> ids;
}

/// Create and attach a new related model in one `SetModelRequest` (`create` array item).
class RelationPickCreate extends RelationPickResult {
  const RelationPickCreate(this.create);

  /// Single model payload, e.g. `{ 'name': '...', 'description': '...' }`.
  final Map<String, dynamic> create;
}

/// Returns a [RelationPickResult] or `null` if dismissed without Done.
Future<RelationPickResult?> showRelationPickerSheet(
  BuildContext context, {
  required String targetModelTypeName,
  required List<int> initialIds,
  bool allowMultiple = true,
}) {
  return showModalBottomSheet<RelationPickResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return _RelationPickerBody(
        targetModelTypeName: targetModelTypeName,
        initialIds: initialIds,
        allowMultiple: allowMultiple,
      );
    },
  );
}

class _RelationPickerBody extends ConsumerStatefulWidget {
  const _RelationPickerBody({
    required this.targetModelTypeName,
    required this.initialIds,
    required this.allowMultiple,
  });

  final String targetModelTypeName;
  final List<int> initialIds;
  final bool allowMultiple;

  @override
  ConsumerState<_RelationPickerBody> createState() => _RelationPickerBodyState();
}

class _RelationPickerBodyState extends ConsumerState<_RelationPickerBody> {
  late Set<int> _sel;
  final _qCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sel = {...widget.initialIds};
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateSheet() async {
    final map = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => _CreateRelationSheet(
        targetModelTypeName: widget.targetModelTypeName,
      ),
    );
    if (!mounted || map == null) return;
    Navigator.pop(context, RelationPickCreate(map));
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(RefLayout.px5, 8, RefLayout.px5, 12),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Select ${widget.targetModelTypeName}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: AppColors.slate900,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, RelationPickLink(_sel.toList())),
            child: Text(
              'Done',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.teal600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(RefLayout.px5, 0, RefLayout.px5, 12),
      child: TextField(
        controller: _qCtrl,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate900),
        decoration: InputDecoration(
          hintText: 'Search ${widget.targetModelTypeName.toLowerCase()}...',
          hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
          prefixIcon: const Icon(Icons.search, color: AppColors.slate400, size: 20),
          filled: true,
          fillColor: AppColors.slate100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _noneRow() {
    if (widget.allowMultiple) return const SizedBox.shrink();
    final on = _sel.isEmpty;
    return _radioRow(
      label: 'None',
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: AppColors.slate400,
      ),
      selected: on,
      onTap: () => setState(() => _sel = {}),
      showDivider: true,
    );
  }

  Widget _radioRow({
    required String label,
    required TextStyle labelStyle,
    required bool selected,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RefLayout.px5, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: labelStyle)),
                  _RelationRadioCircle(selected: selected),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, color: AppColors.slate50),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(relatedModelsProvider(widget.targetModelTypeName));
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final q = _qCtrl.text.trim().toLowerCase();

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const Divider(height: 1, color: AppColors.slate100),
            _searchField(),
            const Divider(height: 1, color: AppColors.slate100),
            Expanded(
              child: async.when(
                data: (models) {
                  final filtered = q.isEmpty
                      ? models
                      : models.where((m) => m.name.toLowerCase().contains(q)).toList();
                  return ListView.builder(
                    itemCount: filtered.length + (widget.allowMultiple ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (!widget.allowMultiple && i == 0) {
                        return _noneRow();
                      }
                      final idx = widget.allowMultiple ? i : i - 1;
                      final m = filtered[idx];
                      final on = _sel.contains(m.id);
                      if (widget.allowMultiple) {
                        return Column(
                          children: [
                            Material(
                              color: Colors.white,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (on) {
                                      _sel.remove(m.id);
                                    } else {
                                      _sel.add(m.id);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: RefLayout.px5, vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.slate900,
                                          ),
                                        ),
                                      ),
                                      Checkbox(
                                        value: on,
                                        activeColor: AppColors.teal600,
                                        onChanged: (v) {
                                          setState(() {
                                            if (v ?? false) {
                                              _sel.add(m.id);
                                            } else {
                                              _sel.remove(m.id);
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.slate50),
                          ],
                        );
                      }
                      return _radioRow(
                        label: m.name,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate900,
                        ),
                        selected: on,
                        onTap: () => setState(() => _sel = {m.id}),
                        showDivider: idx < filtered.length - 1,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: SelectableText('$e')),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(RefLayout.px5, 12, RefLayout.px5, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.slate100)),
              ),
              child: OutlinedButton(
                onPressed: _openCreateSheet,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.slate200, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, color: AppColors.slate500, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Create New ${widget.targetModelTypeName}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationRadioCircle extends StatelessWidget {
  const _RelationRadioCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: selected ? AppColors.teal600 : AppColors.slate300,
          width: selected ? 5 : 1,
        ),
      ),
    );
  }
}

class _CreateRelationSheet extends StatefulWidget {
  const _CreateRelationSheet({required this.targetModelTypeName});

  final String targetModelTypeName;

  @override
  State<_CreateRelationSheet> createState() => _CreateRelationSheetState();
}

class _CreateRelationSheetState extends State<_CreateRelationSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(RefLayout.px5, 8, RefLayout.px5, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New ${widget.targetModelTypeName}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a new record and link it to this expense.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Name *',
                  filled: true,
                  fillColor: AppColors.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  filled: true,
                  fillColor: AppColors.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.teal100.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.teal600.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.teal600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This ${widget.targetModelTypeName} will be saved to your workspace and linked to this expense.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.teal700, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final n = _name.text.trim();
                  if (n.isEmpty) return;
                  final d = _desc.text.trim();
                  final map = <String, dynamic>{'name': n};
                  if (d.isNotEmpty) map['description'] = d;
                  Navigator.pop(context, map);
                },
                child: Text(
                  'Create & Select',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List row that opens the relation picker.
class RelationPickerRow extends ConsumerWidget {
  const RelationPickerRow({
    super.key,
    required this.targetModelTypeName,
    required this.valueIds,
    required this.pendingCreate,
    required this.onPicked,
    this.allowMultiple = true,
  });

  final String targetModelTypeName;
  final List<int> valueIds;
  final Map<String, dynamic>? pendingCreate;
  final void Function(RelationPickResult r) onPicked;
  final bool allowMultiple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(relatedModelsProvider(targetModelTypeName));

    final label = async.maybeWhen(
      data: (models) {
        if (pendingCreate != null) {
          final n = pendingCreate!['name'];
          if (n is String && n.isNotEmpty) return 'New: $n';
          return 'New $targetModelTypeName';
        }
        final ids = dedupeIntIdsPreserveOrder(valueIds);
        final names = <String>[];
        for (final id in ids) {
          for (final m in models) {
            if (m.id == id) {
              names.add(m.name);
              break;
            }
          }
        }
        if (names.isEmpty) return 'Select $targetModelTypeName';
        return names.join(', ');
      },
      orElse: () => pendingCreate != null
          ? 'New: ${pendingCreate!['name'] ?? targetModelTypeName}'
          : 'Select $targetModelTypeName',
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final res = await showRelationPickerSheet(
            context,
            targetModelTypeName: targetModelTypeName,
            initialIds: valueIds,
            allowMultiple: allowMultiple,
          );
          if (res != null) onPicked(res);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  targetModelTypeName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: (valueIds.isEmpty && pendingCreate == null)
                        ? AppColors.slate400
                        : AppColors.slate900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.slate300, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
