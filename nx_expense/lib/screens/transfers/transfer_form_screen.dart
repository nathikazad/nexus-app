import 'package:flutter/foundation.dart' show debugPrint, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_db/src/models/requests/SetModelRequest.dart' as sm;

import '../../app_theme.dart';
import '../../layout.dart';
import '../../providers/expense_providers.dart';
import '../../util/expense_schema.dart';
import '../../widgets/model_attribute_form_field.dart';
import '../../widgets/relation_picker.dart';
import '../../widgets/tag_picker.dart';

/// Create ([transferId] == null) or edit a transfer — name, attributes, **Company**, etc.
class TransferFormScreen extends ConsumerStatefulWidget {
  const TransferFormScreen({
    super.key,
    this.transferId,
    this.prefillFromExpenseId,
  });

  final int? transferId;

  /// When creating from expense form: [prefillFromExpenseId] copies amount, date, company;
  /// on save the expense is **deleted** after the transfer is created (replaces expense).
  final int? prefillFromExpenseId;

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final Map<String, TextEditingController> _attr = {};
  final Map<String, List<String>> _tags = {};
  final Map<String, List<int>> _relations = {};
  final Map<String, Map<String, dynamic>?> _relationCreates = {};
  final Map<String, Map<int, int>> _relationEdgeIds = {};
  Map<String, Set<int>> _relationSnapshotIds = {};
  Map<String, Map<String, dynamic>?> _relationSnapshotCreates = {};
  bool _loading = false;
  bool _seeded = false;
  bool _expensePrefillScheduled = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    for (final c in _attr.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(ModelType schema) {
    for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
      final k = ad.key;
      if (k == null || k.isEmpty) continue;
      _attr.putIfAbsent(k, () => TextEditingController());
    }
    for (final ts in schema.tagSystems ?? const <TagSystem>[]) {
      _tags.putIfAbsent(ts.name, () => []);
    }
    for (final rt in schema.relations ?? const <RelationshipType>[]) {
      final link = rt.link;
      if (link is String && link.isNotEmpty) {
        _relations.putIfAbsent(link, () => []);
        _relationCreates.putIfAbsent(link, () => null);
      }
    }
  }

  void _seedFromModel(ModelType schema, Model m) {
    _name.text = m.name;
    _desc.text = m.description ?? '';
    for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
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
    if (m.relationsList != null) {
      for (final rel in m.relationsList!) {
        _relationEdgeIds
            .putIfAbsent(rel.modelType, () => {})
            [rel.modelId] = rel.relationId;
      }
    }
    _captureRelationSnapshot();
  }

  void _seedFromExpense(Model expense, ModelType expenseSchema, ModelType transferSchema) {
    _name.text = expense.name;
    _desc.text = expense.description ?? '';
    final expAmtKey = primaryNumberAttributeKey(expenseSchema);
    final transAmtKey = primaryNumberAttributeKey(transferSchema);
    if (expAmtKey != null && transAmtKey != null && _attr[transAmtKey] != null) {
      final v = attributeValue(expense, expAmtKey);
      if (v != null) _attr[transAmtKey]!.text = v.toString();
    }
    final rawDate = attributeValue(expense, 'date');
    final dateStr = rawDate is String && rawDate.length >= 10
        ? rawDate.substring(0, 10)
        : (expense.createdAt != null && expense.createdAt!.length >= 10
            ? expense.createdAt!.substring(0, 10)
            : DateTime.now().toIso8601String().substring(0, 10));
    for (final ad in transferSchema.attributes ?? const <AttributeDefinition>[]) {
      final k = ad.key;
      if (k == null) continue;
      final c = _attr[k];
      if (c == null) continue;
      final lk = k.toLowerCase();
      if (lk == 'date') {
        c.text = dateStr;
      }
      if (ad.valueType == 'string' && lk == 'to') {
        c.text = 'Cash';
      }
    }
    final companies = expense.relations?['Company'];
    if (companies != null && companies.isNotEmpty) {
      _relations['Company'] = dedupeIntIdsPreserveOrder(
        companies.map((e) => e.id).toList(),
      );
      _relationCreates['Company'] = null;
    }
    _captureRelationSnapshot();
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

  Future<void> _submit(ModelType schema) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final attrs = <sm.ModelAttribute>[];
      for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
        final k = ad.key;
        if (k == null || !_attr.containsKey(k)) continue;
        final raw = _attr[k]!.text.trim();
        if (raw.isEmpty) continue;
        final vt = ad.valueType ?? 'string';
        dynamic val = raw;
        if (vt == 'number') val = num.tryParse(raw) ?? raw;
        if (vt == 'boolean') val = raw == 'true';
        attrs.add(sm.ModelAttribute(key: k, value: val));
      }

      final tagPayload = <sm.SetModelTag>[];
      for (final e in _tags.entries) {
        if (e.value.isNotEmpty) {
          tagPayload.add(sm.SetModelTag(system: e.key, nodes: e.value));
        }
      }

      final relPayload = <sm.ModelRelation>[];
      final isUpdate = widget.transferId != null;

      for (final e in _relations.entries) {
        final type = e.key;
        final create = _relationCreates[type];

        if (create != null && create.isNotEmpty) {
          relPayload.add(sm.ModelRelation(
            modelType: type,
            create: [create],
          ));
          continue;
        }

        final curIds = dedupeIntIdsPreserveOrder(e.value).toSet();
        final snapIds = _relationSnapshotIds[type] ?? <int>{};

        if (isUpdate) {
          if (setEquals(curIds, snapIds) &&
              relationPendingCreateEquals(
                _relationCreates[type], _relationSnapshotCreates[type])) {
            continue;
          }

          final removed = snapIds.difference(curIds);
          final edgeMap = _relationEdgeIds[type] ?? {};
          for (final modelId in removed) {
            final edgeId = edgeMap[modelId];
            if (edgeId != null) {
              relPayload.add(sm.ModelRelation(id: edgeId, delete: true));
            }
          }

          final added = curIds.difference(snapIds);
          if (added.isNotEmpty) {
            relPayload.add(sm.ModelRelation(
              modelType: type,
              link: added.toList(),
            ));
          }
        } else {
          if (curIds.isNotEmpty) {
            relPayload.add(sm.ModelRelation(
              modelType: type,
              link: curIds.toList(),
            ));
          }
        }
      }

      final req = sm.SetModelRequest(
        id: widget.transferId,
        modelType: widget.transferId == null ? kTransferModelTypeName : null,
        name: _name.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        attributes: attrs.isEmpty ? null : attrs,
        tags: tagPayload.isEmpty ? null : tagPayload,
        relations: relPayload.isEmpty ? null : relPayload,
      );

      debugPrint('[TransferForm] creating/updating transfer transferId=${widget.transferId}');
      await createModel(ref.container, req);
      debugPrint('[TransferForm] transfer save mutation completed');

      if (widget.prefillFromExpenseId != null && widget.transferId == null) {
        debugPrint(
          '[TransferForm] transform flow: deleting expense id=${widget.prefillFromExpenseId}',
        );
        try {
          await createModel(
            ref.container,
            sm.SetModelRequest(
              id: widget.prefillFromExpenseId,
              delete: true,
            ),
          );
          debugPrint('[TransferForm] expense delete mutation completed');
        } catch (e, st) {
          debugPrint('[TransferForm] expense delete FAILED: $e');
          debugPrint('[TransferForm] stack: $st');
          rethrow;
        }
        ref.invalidate(expenseDetailProvider(widget.prefillFromExpenseId!));
        ref.invalidate(expenseListForUiProvider);
        ref.invalidate(expenseSummaryProvider);
      }

      ref.invalidate(transferListProvider);
      ref.invalidate(transferListForUiProvider);
      ref.invalidate(transferListSummaryProvider);
      for (final rt in schema.relations ?? const <RelationshipType>[]) {
        final link = rt.link;
        if (link is String && link.isNotEmpty) {
          ref.invalidate(relatedModelsProvider(link));
        }
      }
      if (widget.transferId != null) {
        ref.invalidate(transferDetailProvider(widget.transferId!));
      }

      if (!mounted) return;
      final msg = widget.prefillFromExpenseId != null && widget.transferId == null
          ? 'Transfer created; expense removed'
          : 'Saved';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/transfers');
      }
    } catch (e, st) {
      debugPrint('[TransferForm] _submit error: $e');
      debugPrint('[TransferForm] stack: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(transferSchemaProvider);

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        _ensureControllers(schema);
        final title = widget.transferId == null ? 'New transfer' : 'Edit transfer';
        final saveLabel = widget.transferId == null ? 'Save transfer' : 'Save changes';

        if (widget.transferId != null) {
          return ref.watch(transferDetailProvider(widget.transferId!)).when(
                loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
                error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
                data: (existing) {
                  if (existing == null) {
                    return Scaffold(
                      appBar: AppBar(),
                      body: const Center(child: Text('Transfer not found')),
                    );
                  }
                  if (!_seeded) {
                    _seeded = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _seedFromModel(schema, existing));
                    });
                  }
                  return _buildFormShell(context, schema, title, saveLabel);
                },
              );
        }

        if (widget.prefillFromExpenseId != null) {
          return ref.watch(expenseSchemaProvider).when(
                loading: () => Scaffold(
                  appBar: AppBar(title: Text(title)),
                  body: const Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
                data: (expenseSchema) {
                  return ref.watch(expenseDetailProvider(widget.prefillFromExpenseId!)).when(
                        loading: () => Scaffold(
                          appBar: AppBar(title: Text(title)),
                          body: const Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
                        data: (expense) {
                          if (expense == null) {
                            return Scaffold(
                              appBar: AppBar(title: Text(title)),
                              body: const Center(child: Text('Expense not found')),
                            );
                          }
                          if (!_expensePrefillScheduled) {
                            _expensePrefillScheduled = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() {
                                _seedFromExpense(expense, expenseSchema, schema);
                                _seeded = true;
                              });
                            });
                          }
                          return _buildFormShell(context, schema, title, saveLabel);
                        },
                      );
                },
              );
        }

        return _buildFormShell(context, schema, title, saveLabel);
      },
    );
  }

  Widget _buildFormShell(
    BuildContext context,
    ModelType schema,
    String title,
    String saveLabel,
  ) {
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
        appBar: AppBar(
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
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _refInputDeco(hint: 'Transfer title'),
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
                              final ads = (schema.attributes ?? const <AttributeDefinition>[])
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
                          Builder(
                            builder: (context) {
                              final systems = schema.tagSystems ?? const <TagSystem>[];
                              if (systems.isEmpty) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 24),
                                  Text('Tags', style: refSectionTitle(context)),
                                  const SizedBox(height: 12),
                                  Container(
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
                                  ),
                                ],
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
                                final rels = schema.relations ?? const <RelationshipType>[];
                                final rows = <Widget>[];
                                for (var i = 0; i < rels.length; i++) {
                                  final rt = rels[i];
                                  final link = rt.link;
                                  if (link is! String || link.isEmpty) continue;
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
                    child: FilledButton(
                      onPressed: () => _submit(schema),
                      child: Text(
                        saveLabel,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                ],
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

}
