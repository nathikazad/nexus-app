import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_db/src/models/requests/SetModelRequest.dart' as sm;

import '../expense_schema.dart';
import '../providers/expense_providers.dart';
import '../widgets/relation_picker.dart';
import '../widgets/tag_picker.dart';

/// Create (`expenseId == null`) or edit.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expenseId});

  final int? expenseId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final Map<String, TextEditingController> _attr = {};
  final Map<String, List<String>> _tags = {};
  final Map<String, List<int>> _relations = {};
  bool _loading = false;
  bool _seeded = false;

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
        _relations[e.key] = e.value.map((x) => x.id).toList();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(expenseSchemaProvider);
    final existingAsync = widget.expenseId != null
        ? ref.watch(expenseDetailProvider(widget.expenseId!))
        : const AsyncValue<Model?>.data(null);

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

            return Scaffold(
              appBar: AppBar(
                title: Text(widget.expenseId == null ? 'New expense' : 'Edit expense'),
              ),
              body: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _desc,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        Text('Attributes', style: Theme.of(context).textTheme.titleMedium),
                        for (final ad in schema.attributes ?? const <AttributeDefinition>[]) ...[
                          if (ad.key != null && _attr.containsKey(ad.key))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _attrField(ad, _attr[ad.key]!),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Text('Tags', style: Theme.of(context).textTheme.titleMedium),
                        for (final ts in schema.tagSystems ?? const <TagSystem>[]) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TagPickerRow(
                                system: ts,
                                value: _tags[ts.name] ?? [],
                                onChanged: (v) => setState(() => _tags[ts.name] = v),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text('Relations', style: Theme.of(context).textTheme.titleMedium),
                        for (final rt in schema.relations ?? const <RelationshipType>[]) ...[
                          if (rt.link is String && (rt.link as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: RelationPickerRow(
                                targetModelTypeName: rt.link as String,
                                valueIds: _relations[rt.link as String] ?? [],
                                onChanged: (ids) =>
                                    setState(() => _relations[rt.link as String] = ids),
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => _submit(schema),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _attrField(AttributeDefinition ad, TextEditingController c) {
    final vt = ad.valueType ?? 'string';
    if (vt == 'boolean') {
      return SwitchListTile(
        title: Text(ad.key ?? ''),
        value: c.text == 'true',
        onChanged: (v) => setState(() => c.text = v ? 'true' : 'false'),
      );
    }
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: ad.key,
        border: const OutlineInputBorder(),
      ),
      keyboardType: vt == 'number'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
    );
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
      for (final e in _relations.entries) {
        if (e.value.isNotEmpty) {
          relPayload.add(sm.ModelRelation(modelType: e.key, link: e.value));
        }
      }

      final req = sm.SetModelRequest(
        id: widget.expenseId,
        modelType: widget.expenseId == null ? kExpenseModelTypeName : null,
        name: _name.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        attributes: attrs.isEmpty ? null : attrs,
        tags: tagPayload.isEmpty ? null : tagPayload,
        relations: relPayload.isEmpty ? null : relPayload,
      );

      await createModel(ref.container, req);
      ref.invalidate(expenseListForUiProvider);
      ref.invalidate(expenseSummaryProvider);
      if (widget.expenseId != null) {
        ref.invalidate(expenseDetailProvider(widget.expenseId!));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
