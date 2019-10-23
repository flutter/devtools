import 'package:flutter/material.dart';

import '../icons.dart';
import 'flutter_icon_renderer.dart';

/// Label including an icon and optional text.
class Label extends StatelessWidget {
  const Label(this.icon, this.text, {this.showText = true});

  final DevToolsIcon icon;
  final String text;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          getIconWidget(icon),
          if (showText)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(text),
            )
        ],
      ),
    );
  }
}
