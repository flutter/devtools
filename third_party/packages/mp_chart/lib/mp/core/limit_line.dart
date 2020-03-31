import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/component.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/enums/limit_label_postion.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class LimitLine extends ComponentBase {
  /// limit / maximum (the y-value or xIndex)
  double _limit = 0;

  /// the width of the limit line
  double _lineWidth = 2;

  /// the color of the limit line
  Color _lineColor = Color.fromARGB(255, 237, 91, 91);

  Color _backgroundColor = Color.fromARGB(255, 255, 255, 0);

  bool _drawBackground = false;

  /// the style of the label text
  PaintingStyle _textStyle = PaintingStyle.fill;

  /// label string that is drawn next to the limit line
  String _label = "";

  /// the path effect of this LimitLine that makes dashed lines possible
  DashPathEffect _dashPathEffect;

  /// indicates the position of the LimitLine label
  LimitLabelPosition _labelPosition = LimitLabelPosition.RIGHT_TOP;

  LimitLine(this._limit, [this._label]);

  double get limit => _limit;

  /// set the line width of the chart (min = 0.2f, max = 12f); default 2f NOTE:
  /// thinner line == better performance, thicker line == worse performance
  ///
  /// @param width
  void setLineWidth(double width) {
    if (width < 0.2) width = 0.2;
    if (width > 12.0) width = 12.0;
    _lineWidth = Utils.convertDpToPixel(width);
  }

  double get lineWidth => _lineWidth;

  // ignore: unnecessary_getters_setters
  Color get lineColor => _lineColor;

  // ignore: unnecessary_getters_setters
  set lineColor(Color value) {
    _lineColor = value;
  }

  /// Enables the line to be drawn in dashed mode, e.g. like this "- - - - - -"
  ///
  /// @param lineLength the length of the line pieces
  /// @param spaceLength the length of space inbetween the pieces
  /// @param phase offset, in degrees (normally, use 0)
  void enableDashedLine(double lineLength, double spaceLength, double phase) {
    _dashPathEffect = DashPathEffect(lineLength, spaceLength, phase);
  }

  /// Disables the line to be drawn in dashed mode.
  void disableDashedLine() {
    _dashPathEffect = null;
  }

  /// Returns true if the dashed-line effect is enabled, false if not. Default:
  /// disabled
  ///
  /// @return
  bool isDashedLineEnabled() {
    return _dashPathEffect == null ? false : true;
  }

  // ignore: unnecessary_getters_setters
  DashPathEffect get dashPathEffect => _dashPathEffect;

  // ignore: unnecessary_getters_setters
  set dashPathEffect(DashPathEffect value) {
    _dashPathEffect = value;
  }

  // ignore: unnecessary_getters_setters
  PaintingStyle get textStyle => _textStyle;

  // ignore: unnecessary_getters_setters
  set textStyle(PaintingStyle value) {
    _textStyle = value;
  }

  // ignore: unnecessary_getters_setters
  LimitLabelPosition get labelPosition => _labelPosition;

  // ignore: unnecessary_getters_setters
  set labelPosition(LimitLabelPosition value) {
    _labelPosition = value;
  }

  // ignore: unnecessary_getters_setters
  String get label => _label;

  // ignore: unnecessary_getters_setters
  set label(String value) {
    _label = value;
  }

  // ignore: unnecessary_getters_setters
  Color get backgroundColor => _backgroundColor;

  // ignore: unnecessary_getters_setters
  set backgroundColor(Color value) {
    _backgroundColor = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawBackground => _drawBackground;

  // ignore: unnecessary_getters_setters
  set drawBackground(bool value) {
    _drawBackground = value;
  }


}
