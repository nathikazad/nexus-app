import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';

import '../providers/expense_providers.dart';

class TagSystemFormScreen extends ConsumerStatefulWidget {
  const TagSystemFormScreen({super.key, this.tagSystemId});

  /// `null` = create.
  final int? tagSystemId;

  @override
  ConsumerState<TagSystemFormScreen> createState() => _TagSystemFormScreenState();
}

class _NodeForm {
  _NodeForm([String initial = '']) : name = TextEditingController(text: initial);
  final TextEditingController name;
  final List<_NodeForm> children = [];

  void dispose() {
    name.dispose();
    for (final c in children) {
      c.dispose();
    }
  }

  SetTagNodeRequest toReq() {
    return SetTagNodeRequest(
      name: name.text.trim().isEmpty ? 'Node' : name.text.trim(),
      children: children.isEmpty ? null : children.map((c) => c.toReq()).toList(),
    );
  }

  static _NodeForm fromTag(TagNode n) {
    final f = _NodeForm(n.name);
    for (final c in n.children ?? const <TagNode>[]) {
      f.children.add(fromTag(c));
    }
    return f;
  }
}

class _TagSystemFormScreenState extends ConsumerState<TagSystemFormScreen> {
  final _name = TextEditingController();
  bool _exclusive = true;
  bool _hierarchical = false;
  final List<TextEditingController> _flatCtrls = [];
  final List<_NodeForm> _hierRoots = [];
  bool _loading = false;
  bool _didInit = false;

  @override
  void dispose() {
    _name.dispose();
    for (final c in _flatCtrls) {
      c.dispose();
    }
    for (final r in _hierRoots) {
      r.dispose();
    }
    super.dispose();
  }

  void _ensureFromSchema(ModelType schema) {
    if (_didInit) return;
    if (widget.tagSystemId == null) {
      _flatCtrls.add(TextEditingController());
      _hierRoots.add(_NodeForm());
      _didInit = true;
      return;
    }
    TagSystem? ts;
    for (final t in schema.tagSystems ?? const <TagSystem>[]) {
      if (t.id == widget.tagSystemId) ts = t;
    }
    if (ts == null) {
      _didInit = true;
      return;
    }
    _name.text = ts.name;
      _exclusive = ts.selectionMode.toLowerCase() == 'exclusive';
      _hierarchical = ts.isHierarchical;
      if (ts.isHierarchical) {
        _hierRoots
          ..clear()
          ..addAll(ts.nodes.map(_NodeForm.fromTag));
        if (_hierRoots.isEmpty) _hierRoots.add(_NodeForm());
      } else {
        void flat(TagNode n) {
          _flatCtrls.add(TextEditingController(text: n.name));
          for (final c in n.children ?? const <TagNode>[]) {
            flat(c);
          }
        }

        _flatCtrls.clear();
        for (final n in ts.nodes) {
          flat(n);
        }
        if (_flatCtrls.isEmpty) _flatCtrls.add(TextEditingController());
      }
    _didInit = true;
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(expenseSchemaProvider);

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        _ensureFromSchema(schema);
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.tagSystemId == null ? 'New tag system' : 'Edit tag system'),
            actions: [
              if (widget.tagSystemId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _loading ? null : () => _delete(schema),
                ),
            ],
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
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Exclusive')),
                        ButtonSegment(value: false, label: Text('Multiple')),
                      ],
                      selected: {_exclusive},
                      onSelectionChanged: (s) =>
                          setState(() => _exclusive = s.isEmpty ? _exclusive : s.first),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Hierarchical'),
                      value: _hierarchical,
                      onChanged: (v) => setState(() => _hierarchical = v),
                    ),
                    const SizedBox(height: 16),
                    Text('Nodes', style: Theme.of(context).textTheme.titleMedium),
                    if (_hierarchical) ...[
                      for (var i = 0; i < _hierRoots.length; i++)
                        _buildHier(_hierRoots[i], 0),
                      TextButton.icon(
                        onPressed: () => setState(() => _hierRoots.add(_NodeForm())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add root'),
                      ),
                    ] else ...[
                      for (var i = 0; i < _flatCtrls.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _flatCtrls[i],
                                  decoration: InputDecoration(
                                    labelText: 'Node ${i + 1}',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  if (_flatCtrls.length <= 1) return;
                                  setState(() {
                                    _flatCtrls[i].dispose();
                                    _flatCtrls.removeAt(i);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () => setState(() => _flatCtrls.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add node'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : () => _save(schema),
                      child: const Text('Save'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHier(_NodeForm node, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: node.name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => node.children.add(_NodeForm())),
              ),
            ],
          ),
          for (final c in node.children) _buildHier(c, depth + 1),
        ],
      ),
    );
  }

  Future<void> _save(ModelType schema) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      List<SetTagNodeRequest> nodes;
      if (_hierarchical) {
        nodes = _hierRoots.map((n) => n.toReq()).toList();
      } else {
        nodes = _flatCtrls
            .map((c) => SetTagNodeRequest(name: c.text.trim().isEmpty ? 'Node' : c.text.trim()))
            .toList();
      }

      final tsReq = SetTagSystemRequest(
        id: widget.tagSystemId,
        name: _name.text.trim(),
        isHierarchical: _hierarchical,
        selectionMode: _exclusive ? 'exclusive' : 'multiple',
        nodes: nodes,
      );

      final req = SetModelTypeRequest(
        id: schema.id,
        name: schema.name,
        typeKind: schema.typeKind ?? 'base',
        tagSystems: [tsReq],
      );

      await createModelType(ref.container, req);
      ref.invalidate(expenseSchemaProvider);
      ref.invalidate(expenseStructProvider);
      ref.invalidate(expenseListForUiProvider);
      ref.invalidate(expenseSummaryProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(ModelType schema) async {
    final id = widget.tagSystemId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tag system?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final req = SetModelTypeRequest(
        id: schema.id,
        name: schema.name,
        typeKind: schema.typeKind ?? 'base',
        tagSystems: [SetTagSystemRequest(id: id, delete: true)],
      );
      await createModelType(ref.container, req);
      ref.invalidate(expenseSchemaProvider);
      ref.invalidate(expenseStructProvider);
      ref.invalidate(expenseListForUiProvider);
      ref.invalidate(expenseSummaryProvider);
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
