import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Formats replies without interpreting the reader's own input as Markdown.
class ReadingCompanionMessage extends StatelessWidget {
  const ReadingCompanionMessage({
    required this.text,
    required this.fromUser,
    super.key,
  });

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium!.copyWith(height: 1.5);
    if (fromUser) return SelectableText(text, style: body);

    return MarkdownBody(
      data: text,
      blockSyntaxes: [_DisplayMathSyntax()],
      inlineSyntaxes: [_InlineMathSyntax(), _LineBreakSyntax()],
      builders: {
        'math-block': _MathBuilder(display: true, textStyle: body),
        'math-inline': _MathBuilder(display: false, textStyle: body),
      },
      selectable: true,
      // Replies should never fetch arbitrary remote images automatically.
      imageBuilder: (uri, title, alt) => Text(alt ?? title ?? 'Image'),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body,
        strong: const TextStyle(fontWeight: FontWeight.w700),
        em: const TextStyle(fontStyle: FontStyle.italic),
        h1: body.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        h2: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        h3: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        listBullet: body,
        blockSpacing: 12,
        listIndent: 20,
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        code: body.copyWith(fontFamily: 'monospace'),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        tableBody: body,
        tableHead: body.copyWith(fontWeight: FontWeight.w700),
        tableBorder: TableBorder.all(color: theme.colorScheme.outlineVariant),
        tableCellsPadding: const EdgeInsets.all(8),
      ),
    );
  }
}

class _DisplayMathSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*(?:\\\[|\$\$)');

  @override
  md.Node parse(md.BlockParser parser) {
    final first = parser.current.content.trim();
    final bracketed = first.startsWith(r'\[');
    final opening = bracketed ? r'\[' : r'$$';
    final closing = bracketed ? r'\]' : r'$$';
    final expression = StringBuffer();
    var remainder = first.substring(opening.length);

    while (true) {
      final closingIndex = remainder.indexOf(closing);
      if (closingIndex >= 0) {
        expression.write(remainder.substring(0, closingIndex));
        parser.advance();
        break;
      }
      expression.writeln(remainder);
      parser.advance();
      if (parser.isDone) break;
      remainder = parser.current.content;
    }

    return md.Element.text('math-block', expression.toString().trim());
  }
}

class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax()
    : super(
        r'(?:\\\((.+?)\\\)|(?<!\\)\$((?:(?!\*\*)(?:\\[A-Za-z]+|[0-9]|[A-Za-z](?![A-Za-z])|[\s+\-*/=<>^_().,{}]))+?)(?<!\\)\$)',
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final parenthesized = match[1];
    final expression = parenthesized ?? match[2]!;
    parser.addNode(md.Element.text('math-inline', expression));
    return true;
  }
}

class _MathBuilder extends MarkdownElementBuilder {
  _MathBuilder({required this.display, required this.textStyle});

  final bool display;
  final TextStyle textStyle;

  @override
  bool isBlockElement() => display;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final source = element.textContent.trim();
    final expression = source.replaceAllMapped(
      RegExp(r'(?<!\\)\$(?=\d)'),
      (_) => r'\$',
    );
    final fallback = SelectableText(
      source,
      style: parentStyle ?? preferredStyle ?? textStyle,
    );
    final math = SelectableMath.tex(
      expression,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: parentStyle ?? preferredStyle ?? textStyle,
      onErrorFallback: (_) => fallback,
    );
    if (!display) return math;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: math,
    );
  }
}

class _LineBreakSyntax extends md.InlineSyntax {
  _LineBreakSyntax() : super(r'<br\s*/?>', caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}
