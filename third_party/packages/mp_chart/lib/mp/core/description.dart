import 'dart:core';
import 'dart:ui';

import 'package:mp_chart/mp/core/component.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class Description extends ComponentBase {
  /// the text used in the description
  String _text = "Description Label";

  /// the custom position of the description text
  MPPointF _position;

  /// the alignment of the description text
  TextAlign _textAlign = TextAlign.center;

  Description() : super() {
    // default size
    textSize = Utils.convertDpToPixel(8);
  }

  String get text => _text;

  set text(String value) {
    _text = value;
  }

  /// Sets a custom position for the description text in pixels on the screen.
  ///
  /// @param x - xcoordinate
  /// @param y - ycoordinate
  void setPosition(double x, double y) {
    if (_position == null) {
      _position = MPPointF.getInstance1(x, y);
    } else {
      _position.x = x;
      _position.y = y;
    }
  }

  MPPointF get position => _position;

  TextAlign get textAlign => _textAlign;

  set textAlign(TextAlign value) {
    _textAlign = value;
  }
}
