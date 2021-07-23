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
import '../utils.dart';

class CustomIcon extends StatelessWidget {
  const CustomIcon({
    @required this.kind,
    @required this.text,
    this.isAbstract = false,
  });

  final IconKind kind;
  final String text;
  final bool isAbstract;

  AssetImageIcon get baseIcon => kind.icon;

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
  final Map<String, Widget> iconCache = {};

  Widget getCustomIcon(String fromText,
      {IconKind kind, bool isAbstract = false}) {
    kind ??= IconKind.classIcon;
    if (fromText?.isEmpty != false) {
      return null;
    }

    final asset = WidgetIcons.getAssetName(fromText);
    if (asset != null) {
      return iconCache.putIfAbsent(fromText, () {
        return AssetImageIcon(asset: asset);
      });
    }

    final String text = fromText[0].toUpperCase();
    final String mapKey = '${text}_${kind.name}_$isAbstract';
    return iconCache.putIfAbsent(mapKey, () {
      return CustomIcon(kind: kind, text: text, isAbstract: isAbstract);
    });
  }

  Widget fromWidgetName(String name) {
    if (name == null) {
      return null;
    }

    while (name.isNotEmpty && !isAlphabetic(name.codeUnitAt(0))) {
      name = name.substring(1);
    }

    if (name.isEmpty) {
      return null;
    }

    return getCustomIcon(
      name,
      kind: isPrivate(name) ? IconKind.method : IconKind.classIcon,
    );
  }

  Widget fromInfo(String name) {
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
  const IconKind(this.name, this.icon, [AssetImageIcon abstractIcon])
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

class AssetImageIcon extends StatelessWidget {
  const AssetImageIcon({
    @required this.asset,
    this.height = defaultIconSize,
    this.width = defaultIconSize,
  });

  final String asset;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: AssetImage(asset),
      height: height,
      width: width,
    );
  }
}

class ThemedImageIcon extends StatelessWidget {
  const ThemedImageIcon({
    @required this.lightModeAsset,
    @required this.darkModeAsset,
  });

  final String lightModeAsset;
  final String darkModeAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Image(
      image: AssetImage(theme.isDarkTheme ? darkModeAsset : lightModeAsset),
      height: defaultIconSize,
      width: defaultIconSize,
    );
  }
}

class WidgetIcons {
  static String getAssetName(String widgetType) {
    if (widgetType == null) {
      return null;
    }

    return _iconMap[_stripBrackets(widgetType)];
  }

  static String _stripBrackets(String widgetType) {
    final bracketIndex = widgetType.indexOf('<');
    if (bracketIndex == -1) {
      return widgetType;
    }

    return widgetType.substring(0, bracketIndex);
  }

  static const Map<String, String> _iconMap = {
    'RenderObjectToWidgetAdapter': root,
    'Text': text,
    'Icon': icon,
    'Image': icon,
    'FloatingActionButton': floatingActionButton,
    'Checkbox': checkbox,
    'Radio': radio,
    'Switch': toggle,
    'AnimatedAlign': animated,
    'AnimatedBuilder': animated,
    'AnimatedContainer': animated,
    'AnimatedCrossFade': animated,
    'AnimatedDefaultTextStyle': animated,
    'AnimatedListState': animated,
    'AnimatedModalBarrier': animated,
    'AnimatedOpacity': animated,
    'AnimatedPhysicalModel': animated,
    'AnimatedPositioned': animated,
    'AnimatedSize': animated,
    'AnimatedWidget': animated,
    'AnimatedWidgetBaseState': animated,
    'DecoratedBoxTransition': transition,
    'FadeTransition': transition,
    'PositionedTransition': transition,
    'RotationTransition': transition,
    'ScaleTransition': transition,
    'SizeTransition': transition,
    'SlideTransition': transition,
    'Hero': hero,
    'Container': container,
    'Center': center,
    'Row': row,
    'Column': column,
    'Padding': padding,
    'Scaffold': scaffold,
    'SizedBox': sizedBox,
    'ConstrainedBox': sizedBox,
    'Expanded': sizedBox,
    'Flex': sizedBox,
    'Align': align,
    'Positioned': align,
    'SingleChildScrollView': scroll,
    'Scrollable': scroll,
    'Stack': stack,
    'InkWell': inkWell,
    'GestureDetector': gesture,
    'TextButton': textButton,
    'RaisedButton': textButton,
    'OutlinedButton': outlinedButton,
    'GridView': gridView,
    'ListView': listView,
  };

  static const String root = 'icons/inspector/widget_icons/root.png';
  static const String text = 'icons/inspector/widget_icons/text.png';
  static const String icon = 'icons/inspector/widget_icons/icon.png';
  static const String image = 'icons/inspector/widget_icons/image.png';
  static const String floatingActionButton =
      'icons/inspector/widget_icons/floatingab.png';
  static const String checkbox = 'icons/inspector/widget_icons/checkbox.png';
  static const String radio = 'icons/inspector/widget_icons/radio.png';
  static const String toggle = 'icons/inspector/widget_icons/toggle.png';
  static const String animated = 'icons/inspector/widget_icons/animated.png';
  static const String transition =
      'icons/inspector/widget_icons/transition.png';
  static const String hero = 'icons/inspector/widget_icons/hero.png';
  static const String container = 'icons/inspector/widget_icons/container.png';
  static const String center = 'icons/inspector/widget_icons/center.png';
  static const String row = 'icons/inspector/widget_icons/row.png';
  static const String column = 'icons/inspector/widget_icons/column.png';
  static const String padding = 'icons/inspector/widget_icons/padding.png';
  static const String scaffold = 'icons/inspector/widget_icons/scaffold.png';
  static const String sizedBox = 'icons/inspector/widget_icons/sizedbox.png';
  static const String align = 'icons/inspector/widget_icons/align.png';
  static const String scroll = 'icons/inspector/widget_icons/scroll.png';
  static const String stack = 'icons/inspector/widget_icons/stack.png';
  static const String inkWell = 'icons/inspector/widget_icons/inkwell.png';
  static const String gesture = 'icons/inspector/widget_icons/gesture.png';
  static const String textButton =
      'icons/inspector/widget_icons/textButton.png';
  static const String outlinedButton =
      'icons/inspector/widget_icons/outlinedbutton.png';
  static const String gridView = 'icons/inspector/widget_icons/gridview.png';
  static const String listView = 'icons/inspector/widget_icons/listView.png';
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
