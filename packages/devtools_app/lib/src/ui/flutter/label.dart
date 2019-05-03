import 'package:flutter/material.dart';

import 'flutter_icon_renderer.dart';

import '../icons.dart';

/// Label including an icon and text with the standard padding appropriate
/// for all kinds of buttons.
class ButtonContent extends StatelessWidget {
  const ButtonContent(this.icon, this.text, {this.showText = true});

  final DevToolsIcon icon;
  final String text;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): add tooltip display.
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
