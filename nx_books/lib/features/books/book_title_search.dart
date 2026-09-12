import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/book/book.dart';

/// Searches the cached library, independently of the bookshelf's lane filters.
class BookTitleSearch extends StatefulWidget {
  const BookTitleSearch({required this.books, required this.onOpen, super.key});
  final List<NxBook> books;
  final ValueChanged<NxBook> onOpen;

  @override
  State<BookTitleSearch> createState() => _BookTitleSearchState();
}

class _BookTitleSearchState extends State<BookTitleSearch> {
  final _overlay = OverlayPortalController();
  final _link = LayerLink();
  final _text = TextEditingController();

  void _close() {
    _overlay.hide();
    _text.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _text.text.trim().toLowerCase();
    final matches =
        widget.books
            .where((book) => book.title.toLowerCase().contains(query))
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.topRight,
            showWhenUnlinked: false,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _close,
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 48,
                  end: math.min(380, MediaQuery.sizeOf(context).width - 120),
                ),
                duration: const Duration(milliseconds: 180),
                builder: (context, width, child) =>
                    SizedBox(width: width, child: child),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _text,
                        autofocus: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Search book titles',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Close search',
                            onPressed: _close,
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (matches.isNotEmpty) {
                            _close();
                            widget.onOpen(matches.first);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      if (matches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No matching titles'),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .55,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: matches.length,
                            itemBuilder: (context, index) => ListTile(
                              title: Text(matches[index].title),
                              onTap: () {
                                _close();
                                widget.onOpen(matches[index]);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: IconButton(
          tooltip: 'Search books',
          icon: const Icon(Icons.search),
          onPressed: _overlay.show,
        ),
      ),
    );
  }
}
