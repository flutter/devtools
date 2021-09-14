import 'package:flutter/material.dart';

import '../utils.dart';

double get _tabHeight => scaleByFontFactor(46.0);
double get _textAndIconTabHeight => scaleByFontFactor(72.0);

class DevToolsTab extends Tab {
  /// Creates a material design [TabBar] tab styled for DevTools.
  ///
  /// The only difference is this tab makes more of an effort to reflect
  /// changes in font and icon sizes.
  DevToolsTab({
    Key key,
    String text,
    Icon icon,
    EdgeInsets iconMargin = const EdgeInsets.only(bottom: 10.0),
    this.gaId,
    Widget child,
  })  : assert(text != null || child != null || icon != null),
        assert(text == null || child == null),
        super(
            key: key,
            text: text,
            icon: icon,
            iconMargin: iconMargin,
            height: calculateHeight(icon, text, child),
            child: child);

  static double calculateHeight(Icon icon, String text, Widget child) {
    if (icon == null || (text == null && child == null)) {
      return _tabHeight;
    } else {
      return _textAndIconTabHeight;
    }
  }

  /// Tab id for google analytics.
  final String gaId;
}
