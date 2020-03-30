import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/axis/axis_base.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/enums/y_axis_label_position.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class YAxis extends AxisBase {
  /// indicates if the bottom y-label entry is drawn or not
  bool _drawBottomYLabelEntry = true;

  /// indicates if the top y-label entry is drawn or not
  bool _drawTopYLabelEntry = true;

  /// flag that indicates if the axis is inverted or not
  bool _inverted = false;

  /// flag that indicates if the zero-line should be drawn regardless of other grid lines
  bool _drawZeroLine = false;

  /// flag indicating that auto scale min restriction should be used
  bool _useAutoScaleRestrictionMin = false;

  /// flag indicating that auto scale max restriction should be used
  bool _useAutoScaleRestrictionMax = false;

  /// Color of the zero line
  Color _zeroLineColor = ColorUtils.GRAY;

  /// Width of the zero line in pixels
  double _zeroLineWidth = 1;

  /// axis space from the largest value to the top in percent of the total axis range
  double _spacePercentTop = 10;

  /// axis space from the smallest value to the bottom in percent of the total axis range
  double _spacePercentBottom = 10;

  /// the position of the y-labels relative to the chart
  YAxisLabelPosition _position = YAxisLabelPosition.OUTSIDE_CHART;

  /// the side this axis object represents
  AxisDependency _axisDependency;

  /// the minimum width that the axis should take (in dp).
  /// <p/>
  /// default: 0.0
  double _minWidth = 0;

  /// the maximum width that the axis can take (in dp).
  /// use Inifinity for disabling the maximum
  /// default: Float.POSITIVE_INFINITY (no maximum specified)
  double _maxWidth = double.infinity;

  YAxis({AxisDependency position = AxisDependency.LEFT}) : super() {
    this._axisDependency = position;
    yOffset = 0;
  }

  AxisDependency get axisDependency => _axisDependency;

  // ignore: unnecessary_getters_setters
  double get minWidth => _minWidth;

  // ignore: unnecessary_getters_setters
  set minWidth(double value) {
    _minWidth = value;
  }

  // ignore: unnecessary_getters_setters
  double get maxWidth => _maxWidth;

  // ignore: unnecessary_getters_setters
  set maxWidth(double value) {
    _maxWidth = value;
  }

  // ignore: unnecessary_getters_setters
  YAxisLabelPosition get position => _position;

  // ignore: unnecessary_getters_setters
  set position(YAxisLabelPosition value) {
    _position = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawTopYLabelEntry => _drawTopYLabelEntry;

  // ignore: unnecessary_getters_setters
  set drawTopYLabelEntry(bool value) {
    _drawTopYLabelEntry = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawBottomYLabelEntry => _drawBottomYLabelEntry;

  // ignore: unnecessary_getters_setters
  set drawBottomYLabelEntry(bool value) {
    _drawBottomYLabelEntry = value;
  }

  // ignore: unnecessary_getters_setters
  bool get inverted => _inverted;

  // ignore: unnecessary_getters_setters
  set inverted(bool value) {
    _inverted = value;
  }

  /// This method is deprecated.
  /// Use setAxisMinimum(...) / setAxisMaximum(...) instead.
  ///
  /// @param startAtZero
  void setStartAtZero(bool startAtZero) {
    if (startAtZero)
      setAxisMinimum(0);
    else
      resetAxisMinimum();
  }

  // ignore: unnecessary_getters_setters
  double get spacePercentTop => _spacePercentTop;

  // ignore: unnecessary_getters_setters
  set spacePercentTop(double value) {
    _spacePercentTop = value;
  }

  // ignore: unnecessary_getters_setters
  double get spacePercentBottom => _spacePercentBottom;

  // ignore: unnecessary_getters_setters
  set spacePercentBottom(double value) {
    _spacePercentBottom = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawZeroLine => _drawZeroLine;

  // ignore: unnecessary_getters_setters
  set drawZeroLine(bool value) {
    _drawZeroLine = value;
  }

  /// Set this to true to draw the zero-line regardless of weather other
  /// grid-lines are enabled or not. Default: false
  ///
  /// @param _drawZeroLine
  void setDrawZeroLine(bool _drawZeroLine) {
    this._drawZeroLine = _drawZeroLine;
  }

  // ignore: unnecessary_getters_setters
  Color get zeroLineColor => _zeroLineColor;

  // ignore: unnecessary_getters_setters
  set zeroLineColor(Color value) {
    _zeroLineColor = value;
  }

  // ignore: unnecessary_getters_setters
  double get zeroLineWidth => _zeroLineWidth;

  // ignore: unnecessary_getters_setters
  set zeroLineWidth(double value) {
    _zeroLineWidth = value;
  }

  /// This is for normal (not horizontal) charts horizontal spacing.
  ///
  /// @param p
  /// @return
  double getRequiredWidthSpace(TextPainter p) {
    p = PainterUtils.create(p, null, null, textSize);
    String label = getLongestLabel();
    double width = Utils.calcTextWidth(p, label) + xOffset * 2;
    if (minWidth > 0) minWidth = Utils.convertDpToPixel(minWidth);
    if (maxWidth > 0 && maxWidth != double.infinity)
      maxWidth = Utils.convertDpToPixel(maxWidth);
    width = max(minWidth, min(width, maxWidth > 0.0 ? maxWidth : width));
    return width;
  }

  /// This is for HorizontalBarChart vertical spacing.
  ///
  /// @param p
  /// @return
  double getRequiredHeightSpace(TextPainter p) {
    p = PainterUtils.create(p, null, null, textSize);

    String label = getLongestLabel();
    return Utils.calcTextHeight(p, label) + yOffset * 2;
  }

  /// Returns true if this axis needs horizontal offset, false if no offset is needed.
  ///
  /// @return
  bool needsOffset() {
    if (enabled && drawLabels && position == YAxisLabelPosition.OUTSIDE_CHART)
      return true;
    else
      return false;
  }

  // ignore: unnecessary_getters_setters
  bool get useAutoScaleRestrictionMin => _useAutoScaleRestrictionMin;

  // ignore: unnecessary_getters_setters
  set useAutoScaleRestrictionMin(bool value) {
    _useAutoScaleRestrictionMin = value;
  }

  // ignore: unnecessary_getters_setters
  bool get useAutoScaleRestrictionMax => _useAutoScaleRestrictionMax;

  // ignore: unnecessary_getters_setters
  set useAutoScaleRestrictionMax(bool value) {
    _useAutoScaleRestrictionMax = value;
  }

  @override
  void calculate(double dataMin, double dataMax) {
    double min = dataMin;
    double max = dataMax;

    double range = (max - min).abs();

    // in case all values are equal
    if (range == 0) {
      max = max + 1;
      min = min - 1;
    }

    // recalculate
    range = (max - min).abs();

    // calc extra spacing
    this.axisMinimum = customAxisMin
        ? this.axisMinimum
        : min - (range / 100) * spacePercentBottom;
    this.axisMaximum = customAxisMax
        ? this.axisMaximum
        : max + (range / 100) * spacePercentTop;

    this.axisRange = (this.axisMinimum - this.axisMaximum).abs();
  }
}
