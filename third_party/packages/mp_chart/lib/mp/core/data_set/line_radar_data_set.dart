import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_line_radar_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/line_scatter_candle_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

abstract class LineRadarDataSet<T extends Entry>
    extends LineScatterCandleRadarDataSet<T> implements ILineRadarDataSet<T> {
  /// the color that is used for filling the line surface
  Color _fillColor = Color.fromARGB(255, 140, 234, 255);

  /**
   * the drawable to be used for filling the line surface
   */
//   Drawable mFillDrawable;

  /// transparency used for filling line surface
  int _fillAlpha = 85;

  /// the width of the drawn data lines
  double _lineWidth = 2.5;

  /// if true, the data will also be drawn filled
  bool _drawFilled = false;

  LineRadarDataSet(List<T> yVals, String label) : super(yVals, label);

  @override
  Color getFillColor() {
    return _fillColor;
  }

  /// Sets the color that is used for filling the area below the line.
  /// Resets an eventually set "fillDrawable".
  ///
  /// @param color
  void setFillColor(Color color) {
    _fillColor = color;
//    mFillDrawable = null;
  }

//  @override
//   Drawable getFillDrawable() {
//    return mFillDrawable;
//  }

  /// Sets the drawable to be used to fill the area below the line.
  ///
  /// @param drawable
//   void setFillDrawable(Drawable drawable) {
//    this.mFillDrawable = drawable;
//  }

  @override
  int getFillAlpha() {
    return _fillAlpha;
  }

  /// sets the alpha value (transparency) that is used for filling the line
  /// surface (0-255), default: 85
  ///
  /// @param alpha
  void setFillAlpha(int alpha) {
    _fillAlpha = alpha;
  }

  /// set the line width of the chart (min = 0.2f, max = 10f); default 1f NOTE:
  /// thinner line == better performance, thicker line == worse performance
  ///
  /// @param width
  void setLineWidth(double width) {
    if (width < 0.0) width = 0.0;
    if (width > 10.0) width = 10.0;
    _lineWidth = Utils.convertDpToPixel(width);
  }

  @override
  double getLineWidth() {
    return _lineWidth;
  }

  @override
  void setDrawFilled(bool filled) {
    _drawFilled = filled;
  }

  @override
  bool isDrawFilledEnabled() {
    return _drawFilled;
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);

    if (baseDataSet is LineRadarDataSet) {
      var lineRadarDataSet = baseDataSet;
      lineRadarDataSet._drawFilled = _drawFilled;
      lineRadarDataSet._fillAlpha = _fillAlpha;
      lineRadarDataSet._fillColor = _fillColor;
//      lineRadarDataSet.mFillDrawable = mFillDrawable;
      lineRadarDataSet._lineWidth = _lineWidth;
    }
  }

  @override
  String toString() {
    return '${super.toString()}\nLineRadarDataSet{_fillColor: $_fillColor,\n _fillAlpha: $_fillAlpha,\n _lineWidth: $_lineWidth,\n _drawFilled: $_drawFilled}';
  }
}
