import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/features/log_edit/feeling_provider.dart';

/// Inline, filterable multi-select for the Feeling tag system.
///
/// Selected chips render above the text field; as the user types, matching
/// available names appear as a dropdown below. Tapping a suggestion adds it
/// to [selected] and clears the input.
class FeelingMultiInput extends ConsumerStatefulWidget {
  const FeelingMultiInput({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  ConsumerState<FeelingMultiInput> createState() => _FeelingMultiInputState();
}

class _FeelingMultiInputState extends ConsumerState<FeelingMultiInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()
      ..addListener(() {
        if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
      });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(String name) {
    if (!widget.selected.contains(name)) {
      widget.onChanged([...widget.selected, name]);
    }
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _remove(String name) {
    widget.onChanged(widget.selected.where((s) => s != name).toList());
  }

  @override
  Widget build(BuildContext context) {
    final namesAsync = ref.watch(feelingNamesProvider);
    final available = namesAsync.value ?? const <String>[];
    final query = _controller.text.trim().toLowerCase();

    final unselected = available
        .where((a) => !widget.selected.contains(a))
        .toList();
    final filtered = query.isEmpty
        ? unselected
        : unselected.where((a) => a.toLowerCase().contains(query)).toList();

    final showDropdown = widget.enabled && _hasFocus && filtered.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.selected.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in widget.selected)
                _SelectedChip(
                  label: f,
                  onRemove: widget.enabled ? () => _remove(f) : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _hasFocus ? AppColors.accent : AppColors.slate200,
              width: _hasFocus ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18, color: AppColors.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: widget.selected.isEmpty
                        ? 'Type to filter feelings…'
                        : 'Add another feeling…',
                    hintStyle: const TextStyle(color: AppColors.slate400),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.slate900,
                  ),
                  onSubmitted: (val) {
                    final t = val.trim();
                    if (t.isEmpty) return;
                    final exact = filtered.firstWhere(
                      (n) => n.toLowerCase() == t.toLowerCase(),
                      orElse: () => '',
                    );
                    if (exact.isNotEmpty) _add(exact);
                  },
                ),
              ),
              if (_controller.text.isNotEmpty)
                _ClearButton(onTap: () => _controller.clear()),
            ],
          ),
        ),
        if (showDropdown) ...[
          const SizedBox(height: 4),
          _Dropdown(options: filtered, query: query, onTap: _add),
        ] else if (widget.enabled &&
            _hasFocus &&
            available.isEmpty &&
            namesAsync is! AsyncLoading) ...[
          const SizedBox(height: 4),
          const _EmptyOptionsHint(),
        ],
      ],
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              child: const Icon(
                Icons.close,
                size: 14,
                color: AppColors.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.close, size: 16, color: AppColors.slate400),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.options,
    required this.query,
    required this.onTap,
  });

  final List<String> options;
  final String query;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.slate100),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.slate200.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: options.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.slate50),
            itemBuilder: (context, i) {
              final name = options[i];
              return InkWell(
                onTap: () => onTap(name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: _HighlightedText(text: name, query: query),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.slate900),
      );
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx < 0) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.slate900),
      );
    }
    final before = text.substring(0, idx);
    final match = text.substring(idx, idx + query.length);
    final after = text.substring(idx + query.length);
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: AppColors.slate900),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _EmptyOptionsHint extends StatelessWidget {
  const _EmptyOptionsHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'No feelings configured yet.',
        style: TextStyle(fontSize: 12, color: AppColors.slate500),
      ),
    );
  }
}
