// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

/// Platform independent definition of icons.
///
/// See [HtmlIconRenderer] for a browser specific implementation of icon
/// rendering. If you add an Icon class you also need to add a renderer class
/// to handle the actual platform specific icon rendering.
/// The benefit of this approach is that icons can be const objects and tests
/// of code that uses icons can run on the Dart VM.
library;

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../screens/inspector/layout_explorer/ui/widgets_theme.dart';
import 'colors.dart';

class CustomIcon extends StatelessWidget {
  const CustomIcon({
    super.key,
    required this.kind,
    required this.text,
    this.isAbstract = false,
  });

  final IconKind kind;
  final String text;
  final bool isAbstract;

  AssetImageIcon get baseIcon => kind.icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: baseIcon.width,
      height: baseIcon.height,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          baseIcon,
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: scaleByFontFactor(9.0),
              color: const Color(0xFF231F20),
            ),
          ),
        ],
      ),
    );
  }
}

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
      // Subtract 1 for a little bit of fixed padding
      // around the icon relative to the default size.
      // TODO(jacobr): consider switching this to padding.
      width: defaultIconSize - 1,
      height: defaultIconSize - 1,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: scaleByFontFactor(9.0),
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class CustomIconMaker {
  final Map<String, Widget> iconCache = {};

  Widget? getCustomIcon(
    String fromText, {
    IconKind? kind,
    bool isAbstract = false,
  }) {
    final theKind = kind ?? IconKind.classIcon;
    if (fromText.isEmpty) {
      return null;
    }

    final String text = fromText[0].toUpperCase();
    final String mapKey = '${text}_${theKind.name}_$isAbstract';
    return iconCache.putIfAbsent(mapKey, () {
      return CustomIcon(kind: theKind, text: text, isAbstract: isAbstract);
    });
  }

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

  CustomIcon fromInfo(String name) {
    return getCustomIcon(name, kind: IconKind.info) as CustomIcon;
  }

  bool isAlphabetic(int char) {
    return (char < '0'.codeUnitAt(0) || char > '9'.codeUnitAt(0)) &&
        char != '_'.codeUnitAt(0) &&
        char != r'$'.codeUnitAt(0);
  }
}

class IconKind {
  const IconKind(this.name, this.icon, [AssetImageIcon? abstractIcon])
      : abstractIcon = abstractIcon ?? icon;

  static IconKind classIcon = const IconKind(
    'class',
    AssetImageIcon(asset: 'icons/custom/class.png'),
    AssetImageIcon(asset: 'icons/custom/class_abstract.png'),
  );
  static IconKind field = const IconKind(
    'fields',
    AssetImageIcon(asset: 'icons/custom/fields.png'),
  );
  static IconKind interface = const IconKind(
    'interface',
    AssetImageIcon(asset: 'icons/custom/interface.png'),
  );
  static IconKind method = const IconKind(
    'method',
    AssetImageIcon(asset: 'icons/custom/method.png'),
    AssetImageIcon(asset: 'icons/custom/method_abstract.png'),
  );
  static IconKind property = const IconKind(
    'property',
    AssetImageIcon(asset: 'icons/custom/property.png'),
  );
  static IconKind info = const IconKind(
    'info',
    AssetImageIcon(asset: 'icons/custom/info.png'),
  );

  final String name;
  final AssetImageIcon icon;
  final AssetImageIcon abstractIcon;
}

class ColorIcon extends StatelessWidget {
  const ColorIcon(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _ColorIconPainter(color, colorScheme),
      size: Size(defaultIconSize, defaultIconSize),
    );
  }
}

class ColorIconMaker {
  final Map<Color, ColorIcon> iconCache = {};

  ColorIcon getCustomIcon(Color color) {
    return iconCache.putIfAbsent(color, () => ColorIcon(color));
  }
}

class _ColorIconPainter extends CustomPainter {
  const _ColorIconPainter(this.color, this.colorScheme);

  final Color color;

  final ColorScheme colorScheme;
  static const double iconMargin = 1;

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
        Paint()..color = colorScheme.background,
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
      ..drawRect(
        iconRect,
        Paint()..color = color,
      )
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
    return Icon(IconData(charCode), color: colorScheme.onPrimary);
  }
}

class AssetImageIcon extends StatelessWidget {
  const AssetImageIcon({
    super.key,
    required this.asset,
    double? height,
    double? width,
  })  : _width = width,
        _height = height;

  final String asset;
  final double? _height;
  final double? _width;

  double get width => _width ?? defaultIconSize;
  double get height => _height ?? defaultIconSize;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: AssetImage(asset),
      height: height,
      width: width,
      fit: BoxFit.fill,
    );
  }
}

class Octicons {
  static const IconData bug = IconData(61714, fontFamily: 'Octicons');
  static const IconData info = IconData(61778, fontFamily: 'Octicons');
  static const IconData deviceMobile = IconData(61739, fontFamily: 'Octicons');
  static const IconData fileZip = IconData(61757, fontFamily: 'Octicons');
  static const IconData clippy = IconData(61724, fontFamily: 'Octicons');
  static const IconData package = IconData(61812, fontFamily: 'Octicons');
  static const IconData dashboard = IconData(61733, fontFamily: 'Octicons');
  static const IconData pulse = IconData(61823, fontFamily: 'Octicons');
}
