// Copyright 2017 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// Platform independent definition of icons.
///
/// If you add an Icon class you also need to add a renderer class to handle the
/// actual platform specific icon rendering.
/// The benefit of this approach is that icons can be const objects and tests
/// of code that uses icons can run on the Dart VM.
library;

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../screens/inspector/layout_explorer/ui/widgets_theme.dart';
import 'colors.dart';

/// An icon with one character
class CircleIcon extends StatelessWidget {
  const CircleIcon({
    super.key,
    required this.text,
    required this.color,
    this.textColor = const Color(0xFF231F20),
  });

  /// Text to display. Should be one character.
  final String text;

  /// Background circle color.
  final Color color;

  /// Background circle color.
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: defaultIconSize,
      height: defaultIconSize,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 9.0, color: textColor),
      ),
    );
  }
}

class CustomIconMaker {
  final iconCache = <String, Widget>{};

  Widget? fromWidgetName(String? name) {
    if (name == null) {
      return null;
    }

    while (name!.isNotEmpty && !isAlphabetic(name.codeUnitAt(0))) {
      name = name.substring(1);
    }

    if (name.isEmpty) {
      return null;
    }

    final widgetTheme = WidgetTheme.fromName(name);
    final icon = widgetTheme.iconAsset;
    if (icon != null) {
      return iconCache.putIfAbsent(name, () {
        return AssetImageIcon(asset: icon);
      });
    }

    final text = name[0].toUpperCase();
    return iconCache.putIfAbsent(name, () {
      return CircleIcon(text: text, color: widgetTheme.color);
    });
  }

  bool isAlphabetic(int char) {
    return (char < '0'.codeUnitAt(0) || char > '9'.codeUnitAt(0)) &&
        char != '_'.codeUnitAt(0) &&
        char != r'$'.codeUnitAt(0);
  }
}

const infoIcon = AssetImageIcon(asset: 'icons/custom/info.png');

class ColorIcon extends StatelessWidget {
  const ColorIcon(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _ColorIconPainter(color, colorScheme),
      size: const Size(defaultIconSize, defaultIconSize),
    );
  }
}

class ColorIconMaker {
  final iconCache = <Color, ColorIcon>{};

  ColorIcon getCustomIcon(Color color) {
    return iconCache.putIfAbsent(color, () => ColorIcon(color));
  }
}

class _ColorIconPainter extends CustomPainter {
  const _ColorIconPainter(this.color, this.colorScheme);

  final Color color;

  final ColorScheme colorScheme;
  static const iconMargin = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    // draw a black and gray grid to use as the background to disambiguate
    // opaque colors from translucent colors.
    final greyPaint = Paint()..color = colorScheme.grey;
    final iconRect = Rect.fromLTRB(
      iconMargin,
      iconMargin,
      size.width - iconMargin,
      size.height - iconMargin,
    );
    canvas
      ..drawRect(
        Rect.fromLTRB(
          iconMargin,
          iconMargin,
          size.width - iconMargin,
          size.height - iconMargin,
        ),
        Paint()..color = colorScheme.surface,
      )
      ..drawRect(
        Rect.fromLTRB(
          iconMargin,
          iconMargin,
          size.width * 0.5,
          size.height * 0.5,
        ),
        greyPaint,
      )
      ..drawRect(
        Rect.fromLTRB(
          size.width * 0.5,
          size.height * 0.5,
          size.width - iconMargin,
          size.height - iconMargin,
        ),
        greyPaint,
      )
      ..drawRect(iconRect, Paint()..color = color)
      ..drawRect(
        iconRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = colorScheme.onPrimary,
      );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is _ColorIconPainter) {
      return oldDelegate.colorScheme.isLight != colorScheme.isLight;
    }
    return true;
  }
}

class FlutterMaterialIcons {
  FlutterMaterialIcons._();

  static Icon getIconForCodePoint(int charCode, ColorScheme colorScheme) {
    return Icon(
      // The code point is dynamic. Flutter Icon Tree Shaking disabled.
      // ignore: non_const_argument_for_const_parameter
      IconData(charCode, fontFamily: 'MaterialIcons'),
      color: colorScheme.onSurface,
    );
  }
}

class Octicons {
  static const bug = IconData(61714, fontFamily: 'Octicons');
}
