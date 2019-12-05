// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Library to render [DevToolsIcon]s as [Widget]s.
library icon_renderer;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../material_icons.dart';
import '../theme.dart';

final Expando<Widget> widgetExpando = Expando('IconRenderer');

typedef DrawIconImageCallback = void Function(Canvas canvas);

String _rewriteIconAssetPath(String path) {
  assert(path.startsWith('/'));
  // Paths under flutter will include the web directory while paths for the
  // legacy dart:html app do not.
  path = 'web$path';
  if (path.endsWith('.png') && !path.endsWith('@2x.png')) {
    // By convention icons all have high DPI verisons with @2x added to the
    // file name.
    // We could opt out of the @2x versions for low DPI devices but there isn't
    // really much harm in using the higher resolution icons on lower DPI
    // displays.
    return '${path.substring(0, path.length - 4)}@2x.png';
  }
  return path;
}

class _ColorIconPainter extends CustomPainter {
  const _ColorIconPainter(this.icon);

  final ColorIcon icon;

  static const double iconMargin = 1;

  Color get color => icon.color;

  @override
  void paint(Canvas canvas, Size size) {
    // draw a black and gray grid to use as the background to disambiguate
    // opaque colors from translucent colors.
    final greyPaint = Paint()..color = grey;
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
        Paint()..color = defaultBackground,
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
          ..color = defaultForeground,
      );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

Widget _computeIconWidget(DevToolsIcon icon) {
  if (icon is UrlIcon) {
    return SizedBox(
      width: icon.iconWidth,
      height: icon.iconHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_rewriteIconAssetPath(icon.src)),
          ),
        ),
      ),
    );
  } else if (icon is ColorIcon) {
    return CustomPaint(
      painter: _ColorIconPainter(icon),
      size: const Size(18, 18),
    );
  } else if (icon is CustomIcon) {
    return Container(
      width: icon.iconWidth,
      height: icon.iconHeight,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          getIconWidget(icon.baseIcon),
          Text(
            icon.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Color(0xFF231F20)),
          ),
        ],
      ),
    );
  } else if (icon is MaterialIcon) {
    // TODO(jacobr): once the dart:html legacy version of this application is
    // removed, start using the regular Flutter material icons directly.
    Widget widget = Icon(
      IconData(
        icon.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      size: icon.iconHeight,
      color: icon.color,
    );
    if (icon.angle != 0) {
      widget = Transform.rotate(
        angle: icon.angle,
        child: widget,
      );
    }
    return SizedBox(
      width: icon.iconWidth,
      height: icon.iconHeight,
      child: widget,
    );
  } else {
    throw UnimplementedError(
        'No icon widget defined for $icon of type ${icon.runtimeType}');
  }
}

Widget getIconWidget(DevToolsIcon icon) {
  Widget widget = widgetExpando[icon];
  if (widget != null) {
    return widget;
  }

  widget = _computeIconWidget(icon);
  widgetExpando[icon] = widget;
  return widget;
}
