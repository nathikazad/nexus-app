import 'package:flutter/material.dart';
import 'package:nx_docs/core/theme/app_theme.dart';
import 'package:nx_docs/domain/document/document.dart';

enum BookCollectionView {
  toRead('to_read', 'To Read'),
  read('read', 'Read');

  const BookCollectionView(this.value, this.label);

  final String value;
  final String label;
}

String bookReadingStateOf(NxDocument document) {
  final value = document.readingState.trim();
  return value.isEmpty ? BookCollectionView.toRead.value : value;
}

List<NxDocument> booksForReadingState(
  List<NxDocument> books,
  String readingState,
) {
  final rows = <NxDocument>[
    for (final book in books)
      if (bookReadingStateOf(book) == readingState) book,
  ];
  rows.sort((a, b) {
    final rank = (a.bookRank ?? 1 << 30).compareTo(b.bookRank ?? 1 << 30);
    if (rank != 0) return rank;
    final updated = b.updatedAt.compareTo(a.updatedAt);
    if (updated != 0) return updated;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return rows;
}

class BookCollectionSwitch extends StatelessWidget {
  const BookCollectionSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final BookCollectionView value;
  final ValueChanged<BookCollectionView> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: AppColors.subtle,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: <Widget>[
        for (final option in BookCollectionView.values)
          Expanded(
            child: Material(
              color: option == value ? AppColors.text : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                key: ValueKey<String>('book-collection-${option.value}'),
                borderRadius: BorderRadius.circular(4),
                onTap: () => onChanged(option),
                child: Center(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      color: option == value ? AppColors.bg : AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

class BookShelfSectionHeader extends StatelessWidget {
  const BookShelfSectionHeader({
    required this.title,
    required this.count,
    this.trailing,
    super.key,
  });

  final String title;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      if (title.isNotEmpty)
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.faint,
              letterSpacing: 0.3,
            ),
          ),
        ),
      if (trailing != null) ...<Widget>[
        if (title.isEmpty)
          Expanded(child: trailing!)
        else
          SizedBox(width: 150, child: trailing!),
        const SizedBox(width: 8),
      ],
      Container(
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.subtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}
