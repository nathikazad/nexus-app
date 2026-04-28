import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nx_cooking/core/theme/app_theme.dart';
import 'package:nx_cooking/data/providers.dart';
import 'package:nx_cooking/data/schema/model_type_kgql_facade.dart';
import 'package:nx_cooking/data/schema/submit_model_type.dart';
import 'package:nx_cooking/domain/schema/model_type_view.dart';

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

  static _NodeForm fromTag(TagNodeView n) {
    final f = _NodeForm(n.name);
    for (final c in n.children ?? const <TagNodeView>[]) {
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

  void _ensureFromSchema(ModelTypeView schema) {
    if (_didInit) return;
    if (widget.tagSystemId == null) {
      _flatCtrls.add(TextEditingController());
      _hierRoots.add(_NodeForm());
      _didInit = true;
      return;
    }
    TagSystemView? ts;
    for (final t in schema.tagSystems) {
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
      void flat(TagNodeView n) {
        _flatCtrls.add(TextEditingController(text: n.name));
        for (final c in n.children ?? const <TagNodeView>[]) {
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
    final schemaAsync = ref.watch(recipeSchemaViewProvider);

    return schemaAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (schema) {
        _ensureFromSchema(schema);
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.zinc500, size: 22),
              onPressed: () => _leaveForm(context, ref),
            ),
            centerTitle: true,
            title: Text(
              widget.tagSystemId == null ? 'New Tag System' : 'Edit Tag System',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.zinc900,
              ),
            ),
            actions: [
              if (widget.tagSystemId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 22),
                  onPressed: _loading ? null : () => _delete(schema),
                ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.zinc100),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        children: [
                          _fieldLabel('Name'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _name,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.zinc200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.zinc200),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _fieldLabel('Selection Mode'),
                          const SizedBox(height: 8),
                          _selectionModePill(),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.zinc200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Hierarchical (Tree)',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.zinc700,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _hierarchical,
                                  activeTrackColor: AppColors.orange500,
                                  inactiveTrackColor: AppColors.zinc200,
                                  onChanged: (v) => setState(() => _hierarchical = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (_hierarchical) ...[
                            _nodesStructureHeader(),
                            const SizedBox(height: 12),
                            _hierarchicalNodeTree(),
                          ] else ...[
                            _nodesStructureHeader(),
                            const SizedBox(height: 12),
                            ..._flatNodeList(),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppColors.zinc100)),
                      ),
                      child: FilledButton(
                        onPressed: _loading ? null : () => _save(schema),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Save System',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// Reference: text-xs font-semibold text-slate-500 uppercase tracking-wider
  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.zinc500,
        letterSpacing: 1.2,
      ),
    );
  }

  /// Reference Screen 7: p-1 bg-slate-100 rounded-xl, white pill on selected half.
  Widget _selectionModePill() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.zinc100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _exclusive = true),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _exclusive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _exclusive
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Exclusive',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _exclusive ? AppColors.zinc900 : AppColors.zinc500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _exclusive = false),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_exclusive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: !_exclusive
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'Multiple',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: !_exclusive ? AppColors.zinc900 : AppColors.zinc500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reference: row with "Nodes Structure" (slate-400) + Add Root (teal).
  Widget _nodesStructureHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'NODES STRUCTURE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.zinc400,
            ),
          ),
        ),
        if (_hierarchical)
          TextButton.icon(
            onPressed: () => setState(() => _hierRoots.add(_NodeForm())),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orange500,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.orange500),
            label: Text(
              'Add Root',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.orange500,
              ),
            ),
          )
        else
          TextButton.icon(
            onPressed: () => setState(() => _flatCtrls.add(TextEditingController())),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orange500,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.orange500),
            label: Text(
              'Add node',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.orange500,
              ),
            ),
          ),
      ],
    );
  }

  /// Reference: border-l-2 border-slate-100 ml-2 pl-2, tree rows with arrow + inputs + icons.
  Widget _hierarchicalNodeTree() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.only(left: 8),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.zinc100, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _hierRoots.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < _hierRoots.length - 1 ? 8 : 0),
              child: _buildTreeNode(
                _hierRoots[i],
                isRoot: true,
                rootIndex: i,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTreeNode(
    _NodeForm node, {
    required bool isRoot,
    int? rootIndex,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.arrow_right, color: AppColors.zinc300, size: 20),
            Expanded(
              child: TextField(
                controller: node.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.zinc900,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.zinc200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.zinc200),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppColors.zinc300, size: 22),
              onPressed: () => setState(() => node.children.add(_NodeForm())),
            ),
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: AppColors.zinc300, size: 22),
              onPressed: () {
                if (!isRoot || rootIndex == null) return;
                if (_hierRoots.length <= 1) return;
                setState(() {
                  _hierRoots[rootIndex].dispose();
                  _hierRoots.removeAt(rootIndex);
                });
              },
            ),
          ],
        ),
        if (node.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 8),
            child: Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.zinc100, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < node.children.length; j++)
                    Padding(
                      padding: EdgeInsets.only(bottom: j < node.children.length - 1 ? 8 : 0),
                      child: _buildChildNode(node, node.children[j], j),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChildNode(_NodeForm parent, _NodeForm child, int childIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 2,
                    margin: const EdgeInsets.only(right: 4),
                    color: AppColors.zinc100,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TextField(
                controller: child.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.zinc900,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.zinc200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.zinc200),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppColors.zinc300, size: 22),
              onPressed: () => setState(() => child.children.add(_NodeForm())),
            ),
            IconButton(
              icon: Icon(Icons.cancel_outlined, color: AppColors.zinc300, size: 22),
              onPressed: () => setState(() {
                child.dispose();
                parent.children.removeAt(childIndex);
              }),
            ),
          ],
        ),
        if (child.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 8),
            child: Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.zinc100, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var k = 0; k < child.children.length; k++)
                    Padding(
                      padding: EdgeInsets.only(bottom: k < child.children.length - 1 ? 8 : 0),
                      child: _buildChildNode(child, child.children[k], k),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _flatNodeList() {
    return [
      for (var i = 0; i < _flatCtrls.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _flatCtrls[i],
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.zinc200),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.cancel_outlined, color: AppColors.zinc300, size: 22),
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
    ];
  }

  Future<void> _save(ModelTypeView schema) async {
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

      await submitSetModelTypeRequest(ref.container, req);
      ref.invalidate(recipeSchemaProvider);
      ref.invalidate(recipeSchemaViewProvider);
      ref.invalidate(recipeListProvider);
      if (mounted) _leaveForm(context, ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _leaveForm(BuildContext context, WidgetRef ref) {
    context.pop();
  }

  Future<void> _delete(ModelTypeView schema) async {
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
      await submitSetModelTypeRequest(ref.container, req);
      ref.invalidate(recipeSchemaProvider);
      ref.invalidate(recipeSchemaViewProvider);
      ref.invalidate(recipeListProvider);
      if (mounted) _leaveForm(context, ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
