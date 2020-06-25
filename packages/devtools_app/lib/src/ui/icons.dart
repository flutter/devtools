/*
 * Copyright 2017 The Chromium Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

/// Platform independent definition of icons.
///
/// See [HtmlIconRenderer] for a browser specific implementation of icon
/// rendering. If you add an Icon class you also need to add a renderer class
/// to handle the actual platform specific icon rendering.
/// The benefit of this approach is that icons can be const objects and tests
/// of code that uses icons can run on the Dart VM.
library icons;

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../theme.dart';
import 'theme.dart';

class CustomIcon extends StatelessWidget {
  const CustomIcon({
    @required this.kind,
    @required this.text,
    this.isAbstract = false,
  });

  final IconKind kind;
  final String text;
  final bool isAbstract;

  Image get baseIcon => kind.icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: baseIcon.width,
      height: baseIcon.height,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          baseIcon,
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Color(0xFF231F20)),
          ),
        ],
      ),
    );
  }
}

class CustomIconMaker {
  final Map<String, CustomIcon> iconCache = {};

  CustomIcon getCustomIcon(String fromText,
      {IconKind kind, bool isAbstract = false}) {
    kind ??= IconKind.classIcon;
    if (fromText?.isEmpty != false) {
      return null;
    }

    final String text = fromText[0].toUpperCase();
    final String mapKey = '${text}_${kind.name}_$isAbstract';

    return iconCache.putIfAbsent(mapKey, () {
      return CustomIcon(kind: kind, text: text, isAbstract: isAbstract);
    });
  }

  CustomIcon fromWidgetName(String name) {
    if (name == null) {
      return null;
    }

    final bool isPrivate = name.startsWith('_');
    while (name.isNotEmpty && !isAlphabetic(name.codeUnitAt(0))) {
      name = name.substring(1);
    }

    if (name.isEmpty) {
      return null;
    }

    return getCustomIcon(
      name,
      kind: isPrivate ? IconKind.method : IconKind.classIcon,
    );
  }

  CustomIcon fromInfo(String name) {
    if (name == null) {
      return null;
    }

    if (name.isEmpty) {
      return null;
    }

    return getCustomIcon(name, kind: IconKind.info);
  }

  bool isAlphabetic(int char) {
    return (char < '0'.codeUnitAt(0) || char > '9'.codeUnitAt(0)) &&
        char != '_'.codeUnitAt(0) &&
        char != r'$'.codeUnitAt(0);
  }
}

class IconKind {
  const IconKind(this.name, this.icon, [Image abstractIcon])
      : abstractIcon = abstractIcon ?? icon;

  static IconKind classIcon = IconKind(
    'class',
    createImageIcon('icons/custom/class.png'),
    createImageIcon('icons/custom/class_abstract.png'),
  );
  static IconKind field = IconKind(
    'fields',
    createImageIcon('icons/custom/fields.png'),
  );
  static IconKind interface = IconKind(
    'interface',
    createImageIcon('icons/custom/interface.png'),
  );
  static IconKind method = IconKind(
    'method',
    createImageIcon('icons/custom/method.png'),
    createImageIcon('icons/custom/method_abstract.png'),
  );
  static IconKind property = IconKind(
    'property',
    createImageIcon('icons/custom/property.png'),
  );
  static IconKind info = IconKind(
    'info',
    createImageIcon('icons/custom/info.png'),
  );

  final String name;
  final Image icon;
  final Image abstractIcon;
}

class ColorIcon extends StatelessWidget {
  const ColorIcon(this.color);

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
        Paint()..color = colorScheme.defaultBackground,
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
          ..color = colorScheme.defaultForeground,
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
    return Icon(IconData(charCode), color: colorScheme.defaultForeground);
  }
}

Image createImageIcon(String url, {double size = defaultIconSize}) {
  return Image(
    image: AssetImage(url),
    height: size,
    width: size,
  );
}
