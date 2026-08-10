import 'package:flutter/material.dart';
import 'package:nx_notes/core/theme/app_theme.dart';
import 'package:nx_notes/domain/ai/conversation_reference.dart';
import 'package:nx_notes/domain/book/book_chapter.dart';
import 'package:nx_notes/domain/book/book_chapter_repository.dart';

class BookChapterConversationPicker extends StatefulWidget {
  const BookChapterConversationPicker({
    required this.bookId,
    required this.repository,
    required this.onStart,
    required this.onCancel,
    super.key,
  });

  final int bookId;
  final BookChapterRepository repository;
  final ValueChanged<List<ConversationReference>> onStart;
  final VoidCallback onCancel;

  @override
  State<BookChapterConversationPicker> createState() =>
      _BookChapterConversationPickerState();
}

class _BookChapterConversationPickerState
    extends State<BookChapterConversationPicker> {
  List<BookChapterSummary>? _chapters;
  final Set<int> _selectedIds = <int>{};
  String? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    setState(() => _error = null);
    try {
      final chapters = await widget.repository.listChapters(widget.bookId);
      if (mounted) setState(() => _chapters = chapters);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _start() async {
    if (_selectedIds.isEmpty || _starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final chapters = await widget.repository.loadSelectedChapters(
        bookId: widget.bookId,
        chapterIds: _selectedIds,
      );
      final references = <ConversationReference>[
        for (final chapter in chapters)
          ConversationReference(
            id: 'book-chapter:${chapter.id}',
            title: chapter.title,
            content: chapter.content,
          ),
      ];
      if (mounted) widget.onStart(references);
    } catch (error) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _chapters;
    return Padding(
      key: const ValueKey<String>('book-chapter-conversation-picker'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('book-chapter-picker-back'),
                tooltip: 'Back to chat',
                onPressed: _starting ? null : widget.onCancel,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back_rounded, size: 19),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Choose chapters',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (chapters != null && chapters.isNotEmpty)
                TextButton(
                  key: const ValueKey<String>('book-chapter-select-all'),
                  onPressed: _starting
                      ? null
                      : () {
                          setState(() {
                            if (_selectedIds.length == chapters.length) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds
                                ..clear()
                                ..addAll(chapters.map((chapter) => chapter.id));
                            }
                          });
                        },
                  child: Text(
                    _selectedIds.length == chapters.length
                        ? 'Clear'
                        : 'Select all',
                  ),
                ),
            ],
          ),
          const Divider(height: 18),
          Expanded(child: _buildBody(chapters)),
          if (_error case final error?) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.red, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${_selectedIds.length} selected',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('book-chapter-start-conversation'),
                onPressed: _selectedIds.isEmpty || _starting ? null : _start,
                icon: _starting
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.graphic_eq_rounded, size: 17),
                label: Text(_starting ? 'Loading' : 'Start'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<BookChapterSummary>? chapters) {
    if (chapters == null && _error == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (chapters == null) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: _loadSummaries,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Retry'),
        ),
      );
    }
    if (chapters.isEmpty) {
      return Center(
        child: Text(
          'No chapters are linked to this book.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      itemCount: chapters.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.line),
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final selected = _selectedIds.contains(chapter.id);
        return CheckboxListTile(
          key: ValueKey<String>('book-chapter-${chapter.id}'),
          value: selected,
          enabled: !_starting,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedIds.add(chapter.id);
              } else {
                _selectedIds.remove(chapter.id);
              }
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            chapter.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          subtitle: chapter.description.isEmpty
              ? null
              : Text(
                  chapter.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.faint, fontSize: 10),
                ),
        );
      },
    );
  }
}
