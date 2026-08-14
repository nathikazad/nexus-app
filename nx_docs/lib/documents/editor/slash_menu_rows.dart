part of 'nx_appflowy_blocks.dart';

abstract class _NxSlashRow {
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  });

  void select();
}

class _NxLinkableModelCommandRow implements _NxSlashRow {
  const _NxLinkableModelCommandRow({
    required this.modelType,
    required this.onSelected,
  });

  final LinkableModelType modelType;
  final VoidCallback onSelected;

  @override
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  }) {
    return _NxSlashTile(
      selected: selected,
      icon: _iconForLinkableModelType(modelType),
      title: modelType.kgqlName,
      subtitle: 'Search ${modelType.kgqlName} models',
      onTap: onSelected,
    );
  }

  @override
  void select() => onSelected();
}

class _NxLinkableModelResultRow implements _NxSlashRow {
  const _NxLinkableModelResultRow({
    this.model,
    this.icon,
    this.title,
    this.subtitle,
    required this.onSelected,
  });

  final LinkedModel? model;
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final VoidCallback onSelected;

  @override
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  }) {
    final model = this.model;
    return _NxSlashTile(
      selected: selected,
      icon: icon ?? _iconForModelTypeName(model?.modelType ?? ''),
      title: title ?? model?.name ?? '',
      subtitle: subtitle ?? model?.modelType,
      onTap: onSelected,
    );
  }

  @override
  void select() => onSelected();
}

class _NxSelectionItemRow implements _NxSlashRow {
  const _NxSelectionItemRow({required this.item, required this.onSelected});

  final SelectionMenuItem item;
  final VoidCallback onSelected;

  @override
  Widget build(
    BuildContext context, {
    required bool selected,
    required EditorState editorState,
    required SelectionMenuStyle style,
  }) {
    return _NxSlashTile(
      selected: selected,
      leading: item.icon(editorState, selected, style),
      title: item.name,
      onTap: onSelected,
    );
  }

  @override
  void select() => onSelected();
}

class _NxSlashTile extends StatelessWidget {
  const _NxSlashTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.icon,
    this.leading,
    this.subtitle,
  });

  final bool selected;
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.subtle : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Center(
                  child:
                      leading ?? Icon(icon, size: 18, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NxSlashMessage extends StatelessWidget {
  const _NxSlashMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, style: TextStyle(color: AppColors.muted, fontSize: 13)),
    );
  }
}

IconData _iconForLinkableModelType(LinkableModelType modelType) {
  return _iconForModelTypeName(modelType.kgqlName);
}

IconData _iconForModelTypeName(String modelType) {
  return switch (modelType) {
    'Project' => Icons.folder_open_outlined,
    'Person' => Icons.person_outline,
    'Company' => Icons.business_outlined,
    'Document' => Icons.article_outlined,
    _ => Icons.link,
  };
}

class _NxSelectionMenuService implements SelectionMenuService {
  _NxSelectionMenuService({required this.entry, required this.style});

  final OverlayEntry entry;

  @override
  final SelectionMenuStyle style;

  @override
  Offset get offset => Offset.zero;

  @override
  Alignment get alignment => Alignment.topLeft;

  @override
  void dismiss() {
    if (entry.mounted) {
      entry.remove();
    }
  }

  @override
  (double? left, double? top, double? right, double? bottom) getPosition() {
    return (null, null, null, null);
  }

  @override
  Future<void> show() async {}
}
