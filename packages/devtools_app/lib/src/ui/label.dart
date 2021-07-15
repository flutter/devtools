import 'package:flutter/material.dart';

import '../theme.dart';
import 'icons.dart';

/// Label including an image icon and optional text.
class ImageIconLabel extends StatelessWidget {
  const ImageIconLabel(this.icon, this.text, {this.minIncludeTextWidth});

  final Widget icon;
  final String text;
  final double minIncludeTextWidth;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      children: [
        icon,
        // TODO(jacobr): animate showing and hiding the text.
        if (includeText(context, minIncludeTextWidth))
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(text),
          ),
      ],
    );
  }
}

class MaterialIconLabel extends StatelessWidget {
  const MaterialIconLabel({
    @required this.label,
    this.iconData,
    this.imageIcon,
    this.color,
    this.includeTextWidth,
  }) : assert((iconData == null) != (imageIcon == null));

  final IconData iconData;
  final ThemedImageIcon imageIcon;
  final Color color;
  final String label;
  final double includeTextWidth;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconData != null
            ? Icon(
                iconData,
                size: defaultIconSize,
                color: color,
              )
            : imageIcon,
        // TODO(jacobr): animate showing and hiding the text.
        if (includeText(context, includeTextWidth))
          Padding(
            padding: const EdgeInsets.only(left: denseSpacing),
            child: Text(
              label,
              style: TextStyle(color: color),
            ),
          ),
      ],
    );
  }
}
