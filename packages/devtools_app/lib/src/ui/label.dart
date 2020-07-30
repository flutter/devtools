import 'package:flutter/material.dart';

/// Label including an image icon and optional text.
class ImageIconLabel extends StatelessWidget {
  const ImageIconLabel(this.icon, this.text, {this.minIncludeTextWidth});

  final Image icon;
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
        createIcon(iconData),
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

Icon createIcon(IconData iconData) => Icon(iconData, size: 18.0);
