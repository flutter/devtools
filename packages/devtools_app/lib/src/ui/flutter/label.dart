import 'package:flutter/material.dart';

import '../icons.dart';
import 'flutter_icon_renderer.dart';

/// Label including an icon and optional text.
class Label extends StatelessWidget {
  const Label(this.icon, this.text, {this.minIncludeTextWidth});

  final DevToolsIcon icon;
  final String text;
  final double minIncludeTextWidth;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): animate showing and hiding the text.
    final showText = minIncludeTextWidth == null ||
        MediaQuery.of(context).size.width >= minIncludeTextWidth;

    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      children: [
        getIconWidget(icon),
        if (showText)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(text),
          )
      ],
    );
  }
}
