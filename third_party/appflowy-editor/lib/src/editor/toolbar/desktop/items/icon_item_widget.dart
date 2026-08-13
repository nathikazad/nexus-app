import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class SVGIconItemWidget extends StatelessWidget {
  const SVGIconItemWidget({
    super.key,
    this.size = const Size.square(30.0),
    this.iconSize = const Size.square(18.0),
    this.iconName,
    this.iconBuilder,
    required this.isHighlight,
    required this.highlightColor,
    this.iconColor,
    this.onPressed,
  });

  final Size size;
  final Size iconSize;
  final String? iconName;
  final WidgetBuilder? iconBuilder;
  final bool isHighlight;
  final Color highlightColor;
  final Color? iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = isHighlight ? highlightColor : iconColor;
    Widget child = iconBuilder != null
        ? iconBuilder!(context)
        : _buildIcon(effectiveIconColor);
    if (onPressed != null) {
      child = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: IconButton(
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          padding: EdgeInsets.zero,
          icon: child,
          iconSize: size.width,
          onPressed: onPressed,
        ),
      );
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: child,
    );
  }

  Widget _buildIcon(Color? effectiveIconColor) {
    final iconData = _materialIconFor(iconName);
    if (iconData != null) {
      return Icon(
        iconData,
        color: effectiveIconColor,
        size: iconSize.shortestSide,
      );
    }

    final headingLevel = _headingLevelFor(iconName);
    if (headingLevel != null) {
      return Center(
        child: Text(
          'H$headingLevel',
          style: TextStyle(
            color: effectiveIconColor,
            fontSize: iconSize.height * 0.72,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      );
    }

    return EditorSvg(
      name: iconName,
      color: effectiveIconColor,
      width: iconSize.width,
      height: iconSize.height,
    );
  }

  IconData? _materialIconFor(String? name) {
    return switch (name) {
      'toolbar/text' => Icons.text_fields,
      'toolbar/underline' => Icons.format_underlined,
      'toolbar/bold' => Icons.format_bold,
      'toolbar/italic' => Icons.format_italic,
      'toolbar/strikethrough' => Icons.format_strikethrough,
      'toolbar/code' => Icons.code,
      'toolbar/quote' => Icons.format_quote,
      'toolbar/bulleted_list' => Icons.format_list_bulleted,
      'toolbar/numbered_list' => Icons.format_list_numbered,
      'toolbar/link' => Icons.link,
      'toolbar/text_color' => Icons.format_color_text,
      'toolbar/highlight_color' => Icons.format_color_fill,
      'toolbar/left' => Icons.format_align_left,
      'toolbar/center' => Icons.format_align_center,
      'toolbar/right' => Icons.format_align_right,
      'toolbar/text_direction_auto' => Icons.format_textdirection_l_to_r,
      'toolbar/text_direction_ltr' => Icons.format_textdirection_l_to_r,
      'toolbar/text_direction_rtl' => Icons.format_textdirection_r_to_l,
      _ => null,
    };
  }

  int? _headingLevelFor(String? name) {
    return switch (name) {
      'toolbar/h1' => 1,
      'toolbar/h2' => 2,
      'toolbar/h3' => 3,
      _ => null,
    };
  }
}
