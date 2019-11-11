import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

abstract class ComponentBase {
  /// flag that indicates if this axis / legend is enabled or not
  bool _enabled = true;

  /// the offset in pixels this component has on the x-axis
  double _xOffset = 5;

  /// the offset in pixels this component has on the Y-axis
  double _yOffset = 5;

  /// the typeface used for the labels
  TypeFace _typeface;

  /// the text size of the labels
  double _textSize = Utils.convertDpToPixel(10);

  /// the text color to use for the labels
  Color _textColor = ColorUtils.BLACK;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
  }

  double get xOffset => _xOffset;

  set xOffset(double value) {
    _xOffset = Utils.convertDpToPixel(value);
  }

  double get yOffset => _yOffset;

  set yOffset(double value) {
    _yOffset = Utils.convertDpToPixel(value);
  }

  TypeFace get typeface => _typeface;

  set typeface(TypeFace value) {
    _typeface = value;
  }

  double get textSize => _textSize;

  set textSize(double value) {
    if (value > 24) value = 24;
    if (value < 6) value = 6;
    _textSize = value;
  }

  Color get textColor => _textColor;

  set textColor(Color value) {
    _textColor = value;
  }
}
