import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import '../providers/expense_providers.dart';

/// Returns selected related model IDs (by [Model.id]).
Future<List<int>?> showRelationPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetModelTypeName,
  required List<int> initialIds,
  bool allowMultiple = true,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
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
  String _q = '';

  @override
  void initState() {
    super.initState();
    _sel = {...widget.initialIds};
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(relatedModelsProvider(widget.targetModelTypeName));
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.targetModelTypeName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: async.when(
                  data: (models) {
                    final filtered = _q.isEmpty
                        ? models
                        : models
                            .where((m) => m.name.toLowerCase().contains(_q))
                            .toList();
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final m = filtered[i];
                        final on = _sel.contains(m.id);
                        return ListTile(
                          title: Text(m.name),
                          leading: widget.allowMultiple
                              ? Checkbox(
                                  value: on,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v ?? false) {
                                        _sel.add(m.id);
                                      } else {
                                        _sel.remove(m.id);
                                      }
                                    });
                                  },
                                )
                              : Radio<int>(
                                  value: m.id,
                                  groupValue: _sel.isEmpty ? null : _sel.first,
                                  onChanged: (_) => setState(() => _sel = {m.id}),
                                ),
                          onTap: () {
                            setState(() {
                              if (widget.allowMultiple) {
                                if (on) {
                                  _sel.remove(m.id);
                                } else {
                                  _sel.add(m.id);
                                }
                              } else {
                                _sel = {m.id};
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => SelectableText('$e'),
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _sel.toList()),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RelationPickerRow extends ConsumerWidget {
  const RelationPickerRow({
    super.key,
    required this.targetModelTypeName,
    required this.valueIds,
    required this.onChanged,
    this.allowMultiple = true,
  });

  final String targetModelTypeName;
  final List<int> valueIds;
  final ValueChanged<List<int>> onChanged;
  final bool allowMultiple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(relatedModelsProvider(targetModelTypeName));
    final label = async.maybeWhen(
      data: (models) {
        final names = models.where((m) => valueIds.contains(m.id)).map((m) => m.name).toList();
        if (names.isEmpty) return 'Select $targetModelTypeName';
        return names.join(', ');
      },
      orElse: () => 'Select $targetModelTypeName',
    );

    return OutlinedButton.icon(
      onPressed: () async {
        final res = await showRelationPickerSheet(
          context,
          ref,
          targetModelTypeName: targetModelTypeName,
          initialIds: valueIds,
          allowMultiple: allowMultiple,
        );
        if (res != null) onChanged(res);
      },
      icon: const Icon(Icons.link),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
