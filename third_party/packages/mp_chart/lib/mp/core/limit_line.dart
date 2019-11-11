import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/component.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/enums/limite_label_postion.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class LimitLine extends ComponentBase {
  /// limit / maximum (the y-value or xIndex)
  double _limit = 0;

  /// the width of the limit line
  double _lineWidth = 2;

  /// the color of the limit line
  Color _lineColor = Color.fromARGB(255, 237, 91, 91);

  /// the style of the label text
  PaintingStyle _textStyle = PaintingStyle.fill;

  /// label string that is drawn next to the limit line
  String _label = "";

  /// the path effect of this LimitLine that makes dashed lines possible
  DashPathEffect _dashPathEffect = null;

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

  Color get lineColor => _lineColor;

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

  DashPathEffect get dashPathEffect => _dashPathEffect;

  set dashPathEffect(DashPathEffect value) {
    _dashPathEffect = value;
  }

  PaintingStyle get textStyle => _textStyle;

  set textStyle(PaintingStyle value) {
    _textStyle = value;
  }

  LimitLabelPosition get labelPosition => _labelPosition;

  set labelPosition(LimitLabelPosition value) {
    _labelPosition = value;
  }

  String get label => _label;

  set label(String value) {
    _label = value;
  }
}
