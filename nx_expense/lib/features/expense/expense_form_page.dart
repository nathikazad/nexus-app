import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nx_expense/core/layout/layout.dart';
import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/data/providers.dart';
import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_upsert.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/schema/model_type_view.dart';
import 'package:nx_expense/features/desktop/desktop_nav.dart';
import 'package:nx_expense/features/expense/expense_list_view_model.dart';
import 'widgets/expense_bills_section.dart';
import 'widgets/expense_teller_links_section.dart';
import 'widgets/model_attribute_form_field.dart';
import 'widgets/relation_picker.dart';
import 'widgets/tag_picker.dart';

/// Create (`expenseId == null`) or edit. Layout matches reference Screen 4.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({
    super.key,
    this.expenseId,
    this.pendingTellerEventId,
    this.pendingTellerEventTime,
    this.prefillName,
    this.prefillDescription,
    this.prefillAmount,
    this.embedded = false,
  });

  final int? expenseId;

  /// Desktop Teller panel 3: no app bar; close via [desktop_nav.closeTellerPanel3].
  final bool embedded;

  /// When creating, link to this Teller timeline row after save (`/expense/form?...`).
  final String? pendingTellerEventId;
  final DateTime? pendingTellerEventTime;

  final String? prefillName;
  final String? prefillDescription;
  final num? prefillAmount;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final Map<String, TextEditingController> _attr = {};
  final Map<String, List<String>> _tags = {};
  final Map<String, List<int>> _relations = {};
  /// Pending `ModelRelation.create` payload per relation target type key (`link` string).
  final Map<String, Map<String, dynamic>?> _relationCreates = {};
  /// Maps relation type → (model ID → relation edge ID) from the generic `relations` node.
  /// Used to issue `ModelRelation(id: edgeId, delete: true)` for removed links.
  final Map<String, Map<int, int>> _relationEdgeIds = {};
  /// Snapshot of linked model IDs per type at load time — used to compute add/remove deltas.
  Map<String, Set<int>> _relationSnapshotIds = {};
  Map<String, Map<String, dynamic>?> _relationSnapshotCreates = {};
  bool _loading = false;
  bool _seeded = false;
  bool _tellerPrefillApplied = false;
  bool _tellerPrefillScheduled = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    for (final c in _attr.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(ModelTypeView schema) {
    for (final ad in schema.attributes) {
      final k = ad.key;
      if (k == null || k.isEmpty) continue;
      _attr.putIfAbsent(k, () => TextEditingController());
    }
    for (final ts in schema.tagSystems) {
      _tags.putIfAbsent(ts.name, () => []);
    }
    for (final rt in schema.relations) {
      final link = rt.link;
      if (link.isNotEmpty) {
        _relations.putIfAbsent(link, () => []);
        _relationCreates.putIfAbsent(link, () => null);
      }
    }
  }

  void _seedFromModel(ModelTypeView schema, Expense m) {
    _name.text = m.name;
    _desc.text = m.description ?? '';
    for (final ad in schema.attributes) {
      final k = ad.key;
      if (k == null) continue;
      final ctrl = _attr[k];
      if (ctrl == null) continue;
      final v = attributeValue(m, k);
      if (v == null) {
        ctrl.clear();
      } else if (ad.valueType == 'boolean') {
        ctrl.text = v == true || v == 'true' ? 'true' : 'false';
      } else {
        ctrl.text = v.toString();
      }
    }
    if (m.tags != null) {
      for (final e in m.tags!.entries) {
        _tags[e.key] = [...e.value];
      }
    }
    if (m.relations != null) {
      for (final e in m.relations!.entries) {
        _relations[e.key] = dedupeIntIdsPreserveOrder(
          e.value.map((x) => x.id).toList(),
        );
        _relationCreates[e.key] = null;
      }
    }
    // Build modelId → relationEdgeId mapping from the generic `relations` node.
    if (m.relationsList != null) {
      for (final rel in m.relationsList!) {
        _relationEdgeIds
            .putIfAbsent(rel.modelType, () => {})
            [rel.modelId] = rel.relationId;
      }
    }
    _captureRelationSnapshot();
  }

  void _applyTellerPrefill(ModelTypeView schema) {
    if (_tellerPrefillApplied || widget.expenseId != null) return;
    if (widget.prefillName == null &&
        widget.prefillDescription == null &&
        widget.prefillAmount == null) {
      _tellerPrefillApplied = true;
      return;
    }
    _tellerPrefillApplied = true;
    if (widget.prefillName != null) {
      _name.text = widget.prefillName!;
    }
    if (widget.prefillDescription != null) {
      _desc.text = widget.prefillDescription!;
    }
    final pk = primaryNumberAttributeKey(schema);
    if (pk != null && widget.prefillAmount != null && _attr[pk] != null) {
      _attr[pk]!.text = widget.prefillAmount!.toString();
    }
  }

  void _captureRelationSnapshot() {
    _relationSnapshotIds = {
      for (final e in _relations.entries)
        e.key: dedupeIntIdsPreserveOrder([...e.value]).toSet(),
    };
    _relationSnapshotCreates = {
      for (final e in _relationCreates.entries)
        e.key: e.value == null ? null : Map<String, dynamic>.from(e.value!),
    };
  }

  void _onRelationPicked(String relKey, RelationPickResult r) {
    setState(() {
      if (r is RelationPickLink) {
        _relations[relKey] = dedupeIntIdsPreserveOrder([...r.ids]);
        _relationCreates[relKey] = null;
      } else if (r is RelationPickCreate) {
        _relations[relKey] = [];
        _relationCreates[relKey] = r.create;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(expenseSchemaViewProvider);
    final existingAsync = widget.expenseId != null
        ? ref.watch(expenseDetailProvider(widget.expenseId!))
        : const AsyncValue<Expense?>.data(null);

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        _ensureControllers(schema);
        return existingAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (existing) {
            if (widget.expenseId != null && existing == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Expense not found')),
              );
            }
            if (existing != null && !_seeded) {
              _seeded = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _seedFromModel(schema, existing));
                }
              });
            }
            if (existing == null &&
                widget.expenseId == null &&
                !_tellerPrefillApplied &&
                !_tellerPrefillScheduled) {
              _tellerPrefillScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _applyTellerPrefill(schema));
              });
            }

            final title = widget.expenseId == null ? 'New Expense' : 'Edit Expense';

            final saveLabel = widget.expenseId == null ? 'Save Expense' : 'Save Changes';

            return Theme(
              data: Theme.of(context).copyWith(
                switchTheme: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return Colors.white;
                    return AppColors.slate400;
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.teal600;
                    return AppColors.slate200;
                  }),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ),
              child: Scaffold(
              backgroundColor: Colors.white,
              appBar: widget.embedded
                  ? null
                  : AppBar(
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 22),
                        onPressed: () => context.pop(),
                      ),
                      centerTitle: true,
                      title: Text(title, style: refAppBarTitleBase()),
                      bottom: const PreferredSize(
                        preferredSize: Size.fromHeight(1),
                        child: Divider(height: 1, color: AppColors.slate100),
                      ),
                    ),
              body: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Expanded(
                          child: ColoredBox(
                            color: const Color(0x4DF8FAFC),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(RefLayout.px5, 20, RefLayout.px5, 120),
                              children: [
                                _refLabel('Name *'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _name,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                                  decoration: _refInputDeco(hint: 'E.g., Groceries'),
                                ),
                                const SizedBox(height: 16),
                                _refLabel('Description'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _desc,
                                  maxLines: 3,
                                  style: GoogleFonts.inter(fontSize: 14),
                                  decoration: _refInputDeco(hint: 'Add details...'),
                                ),
                                const SizedBox(height: 24),
                                Text('Attributes', style: refSectionTitle(context)),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final ads = schema.attributes
                                        .where((ad) => ad.key != null && _attr.containsKey(ad.key))
                                        .toList();
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                                        border: Border.all(color: AppColors.slate100),
                                        boxShadow: refCardShadow,
                                      ),
                                      child: Column(
                                        children: [
                                          for (var i = 0; i < ads.length; i++) ...[
                                            ModelAttributeFormField(
                                              attribute: ads[i],
                                              controller: _attr[ads[i].key]!,
                                              onChanged: () => setState(() {}),
                                              inputDecoration: _refInputDeco(hint: ''),
                                            ),
                                            if (i < ads.length - 1)
                                              const Divider(height: 1, color: AppColors.slate50),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                Text('Tags', style: refSectionTitle(context)),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final systems = schema.tagSystems;
                                    if (systems.isEmpty) {
                                      return Text(
                                        'No tag systems',
                                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
                                      );
                                    }
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                                        border: Border.all(color: AppColors.slate100),
                                        boxShadow: refCardShadow,
                                      ),
                                      child: Column(
                                        children: [
                                          for (var i = 0; i < systems.length; i++) ...[
                                            TagPickerRow(
                                              system: systems[i],
                                              value: _tags[systems[i].name] ?? [],
                                              onChanged: (v) =>
                                                  setState(() => _tags[systems[i].name] = v),
                                            ),
                                            if (i < systems.length - 1)
                                              const Divider(height: 1, color: AppColors.slate50),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                Text('Relations', style: refSectionTitle(context)),
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                                    border: Border.all(color: AppColors.slate100),
                                    boxShadow: refCardShadow,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Builder(
                                    builder: (context) {
                                      final relsAll = schema.relations;
                                      final rels = relsAll.where((rt) {
                                        final link = rt.link;
                                        return link.isNotEmpty &&
                                            link != kTransferModelTypeName;
                                      }).toList();
                                      final rows = <Widget>[];
                                      for (var i = 0; i < rels.length; i++) {
                                        final rt = rels[i];
                                        final link = rt.link;
                                        rows.add(
                                          RelationPickerRow(
                                            targetModelTypeName: link,
                                            valueIds: _relations[link] ?? [],
                                            pendingCreate: _relationCreates[link],
                                            allowMultiple: (rt.multiplicity ?? 'many') != 'one',
                                            onPicked: (r) => _onRelationPicked(link, r),
                                          ),
                                        );
                                        if (i < rels.length - 1) {
                                          rows.add(
                                            const Divider(height: 1, color: AppColors.slate50),
                                          );
                                        }
                                      }
                                      return Column(children: rows);
                                    },
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    RelationTypeView? transferRt;
                                    for (final rt in schema.relations) {
                                      final link = rt.link;
                                      if (link == kTransferModelTypeName) {
                                        transferRt = rt;
                                        break;
                                      }
                                    }
                                    if (transferRt == null) return const SizedBox.shrink();
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const SizedBox(height: 24),
                                        Text('Transfer', style: refSectionTitle(context)),
                                        const SizedBox(height: 12),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(RefLayout.rounded2xl),
                                            border: Border.all(color: AppColors.slate100),
                                            boxShadow: refCardShadow,
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: RelationPickerRow(
                                            targetModelTypeName: kTransferModelTypeName,
                                            valueIds: _relations[kTransferModelTypeName] ?? [],
                                            pendingCreate: _relationCreates[kTransferModelTypeName],
                                            allowMultiple:
                                                (transferRt.multiplicity ?? 'many') != 'one',
                                            onPicked: (r) =>
                                                _onRelationPicked(kTransferModelTypeName, r),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                if (widget.expenseId != null) ...[
                                  const SizedBox(height: 24),
                                  ExpenseTellerLinksFormSection(expenseId: widget.expenseId!),
                                  const SizedBox(height: 24),
                                  ExpenseBillsSection(expenseId: widget.expenseId!),
                                  const SizedBox(height: 24),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.swap_horiz_outlined, size: 20),
                                    label: Text(
                                      'Transform to transfer',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    onPressed: () {
                                      context.push(
                                        '/transfer/form?fromExpenseId=${widget.expenseId}',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    label: Text(
                                      'Delete Expense',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    onPressed: () async {
                                      debugPrint(
                                        '[ExpenseForm] Delete expense tapped id=${widget.expenseId}',
                                      );
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete expense?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok != true || !context.mounted) {
                                        debugPrint(
                                          '[ExpenseForm] Delete cancelled or unmounted',
                                        );
                                        return;
                                      }
                                      try {
                                        debugPrint(
                                          '[ExpenseForm] calling deleteById id=${widget.expenseId}',
                                        );
                                        await ref
                                            .read(expenseRepositoryProvider)
                                            .deleteById(widget.expenseId!);
                                        debugPrint(
                                          '[ExpenseForm] delete succeeded, invalidating + go /expenses',
                                        );
                                        invalidateExpenseListCache(ref);
                                        if (context.mounted) context.go('/expenses');
                                      } catch (e, st) {
                                        debugPrint('[ExpenseForm] delete FAILED: $e');
                                        debugPrint('[ExpenseForm] stack: $st');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('$e')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(RefLayout.px5, 12, RefLayout.px5, 28),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: AppColors.slate100)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                onPressed: () => _submit(schema),
                                child: Text(
                                  saveLabel,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _refLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.slate500,
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _refInputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
    );
  }

  Future<void> _submit(ModelTypeView schema) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final attrsMap = <String, dynamic>{};
      for (final ad in schema.attributes) {
        final k = ad.key;
        if (k == null || !_attr.containsKey(k)) continue;
        final raw = _attr[k]!.text.trim();
        if (raw.isEmpty) continue;
        final vt = ad.valueType ?? 'string';
        dynamic val = raw;
        if (vt == 'number') val = num.tryParse(raw) ?? raw;
        if (vt == 'boolean') val = raw == 'true';
        attrsMap[k] = val;
      }

      final repo = ref.read(expenseRepositoryProvider);
      final upsert = ExpenseUpsert(
        id: widget.expenseId,
        name: _name.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        attributes: attrsMap,
        tags: {
          for (final e in _tags.entries) e.key: List<String>.from(e.value),
        },
        relationsByType: {
          for (final e in _relations.entries) e.key: List<int>.from(e.value),
        },
        relationCreatesByType:
            Map<String, Map<String, dynamic>?>.from(_relationCreates),
        relationEdgeIdsByType: {
          for (final e in _relationEdgeIds.entries)
            e.key: Map<int, int>.from(e.value),
        },
        snapshotLinkIdsByType: {
          for (final e in _relationSnapshotIds.entries)
            e.key: Set<int>.from(e.value),
        },
        snapshotCreatesByType:
            Map<String, Map<String, dynamic>?>.from(_relationSnapshotCreates),
      );

      final savedId = await repo.upsert(upsert);
      invalidateExpenseListCache(ref);
      for (final rt in schema.relations) {
        final link = rt.link;
        if (link.isNotEmpty) {
          ref.invalidate(relatedModelsProvider(link));
        }
      }
      if (widget.expenseId != null) {
        ref.invalidate(expenseDetailProvider(widget.expenseId!));
        ref.invalidate(expenseTimelineLinksProvider(widget.expenseId!));
      }
      if (widget.expenseId == null &&
          widget.pendingTellerEventId != null &&
          widget.pendingTellerEventTime != null) {
        await repo.linkExpenseToTellerTimeline(
          expenseId: savedId,
          tellerEventId: widget.pendingTellerEventId!,
          tellerEventTime: widget.pendingTellerEventTime!,
        );
        ref.invalidate(expenseTimelineLinksProvider(savedId));
        if (mounted && isDesktopLayout(context)) {
          await refreshTellerSelectionAfterLinkChange(
            ref,
            widget.pendingTellerEventId!,
          );
        } else {
          ref.invalidate(tellerTransactionsProvider);
        }
      }
      if (mounted) {
        if (widget.embedded) {
          closeTellerPanel3(ref);
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// Centered modal: name + cost, then full form at `/expense/form/:id`.
void showAddExpenseModal(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (ctx) => const _AddExpenseModal(),
  );
}

class _AddExpenseModal extends ConsumerStatefulWidget {
  const _AddExpenseModal();

  @override
  ConsumerState<_AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends ConsumerState<_AddExpenseModal> {
  final _name = TextEditingController();
  final _cost = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RefLayout.rounded2xl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'New Expense',
                      style: refAppBarTitleBase(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.slate400, size: 22),
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _refLabel('Name *'),
                const SizedBox(height: 6),
                TextField(
                  controller: _name,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: _refInputDeco(hint: 'E.g., Groceries'),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                _refLabel('Cost *'),
                const SizedBox(height: 6),
                TextField(
                  controller: _cost,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _refInputDeco(hint: '0.00'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submit,
                  child: Text(
                    'Create',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _refLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.slate500,
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _refInputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
    );
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    final costRaw = _cost.text.trim().replaceFirst(RegExp(r'^\$\s*'), '');
    if (costRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cost is required')),
      );
      return;
    }
    final costNum = num.tryParse(costRaw);
    if (costNum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid cost')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final id = await repo.createMinimalExpense(
        name: _name.text.trim(),
        amount: costNum,
      );
      invalidateExpenseListCache(ref);
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/expense/form/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
