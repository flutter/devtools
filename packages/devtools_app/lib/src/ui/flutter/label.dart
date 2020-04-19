import 'package:flutter/material.dart';

import '../icons.dart';
import 'flutter_icon_renderer.dart';

/// Label including an icon and optional text.
// TODO(kenz): this class can be removed in favor of [MaterialIconLabel] once we
// no longer need to support icons for both the flutter app and the html app.
class Label extends StatelessWidget {
  const Label(this.icon, this.text, {this.minIncludeTextWidth});

  final DevToolsIcon icon;
  final String text;
  final double minIncludeTextWidth;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      children: [
        getIconWidget(icon),
        // TODO(jacobr): animate showing and hiding the text.
        if (_showLabelText(context, minIncludeTextWidth))
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(text),
          ),
      ],
    );
  }
}

class MaterialIconLabel extends StatelessWidget {
  const MaterialIconLabel(this.iconData, this.text, {this.includeTextWidth});

  final IconData iconData;
  final String text;
  final double includeTextWidth;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      children: [
        Icon(iconData, size: 18.0),
        // TODO(jacobr): animate showing and hiding the text.
        if (_showLabelText(context, includeTextWidth))
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(text),
          ),
      ],
    );
  }
}

bool _showLabelText(BuildContext context, double includeTextWidth) {
  return includeTextWidth == null ||
      MediaQuery.of(context).size.width > includeTextWidth;
}
