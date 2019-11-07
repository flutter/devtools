import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_radar_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/data_set.dart';
import 'package:mp_chart/mp/core/data_set/line_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/radar_entry.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';

class RadarDataSet extends LineRadarDataSet<RadarEntry>
    implements IRadarDataSet {
  /// flag indicating whether highlight circle should be drawn or not
  bool _drawHighlightCircleEnabled = false;

  Color _highlightCircleFillColor = ColorUtils.WHITE;

  /// The stroke color for highlight circle.
  /// If Utils.COLOR_NONE, the color of the dataset is taken.
  Color _highlightCircleStrokeColor = ColorUtils.COLOR_NONE;

  int _highlightCircleStrokeAlpha = (0.3 * 255).toInt();
  double _highlightCircleInnerRadius = 3.0;
  double _highlightCircleOuterRadius = 4.0;
  double _highlightCircleStrokeWidth = 2.0;

  RadarDataSet(List<RadarEntry> yVals, String label) : super(yVals, label);

  /// Returns true if highlight circle should be drawn, false if not
  @override
  bool isDrawHighlightCircleEnabled() {
    return _drawHighlightCircleEnabled;
  }

  /// Sets whether highlight circle should be drawn or not
  @override
  void setDrawHighlightCircleEnabled(bool enabled) {
    _drawHighlightCircleEnabled = enabled;
  }

  @override
  Color getHighlightCircleFillColor() {
    return _highlightCircleFillColor;
  }

  void setHighlightCircleFillColor(Color color) {
    _highlightCircleFillColor = color;
  }

  /// Returns the stroke color for highlight circle.
  /// If Utils.COLOR_NONE, the color of the dataset is taken.
  @override
  Color getHighlightCircleStrokeColor() {
    return _highlightCircleStrokeColor;
  }

  /// Sets the stroke color for highlight circle.
  /// Set to Utils.COLOR_NONE in order to use the color of the dataset;
  void setHighlightCircleStrokeColor(Color color) {
    _highlightCircleStrokeColor = color;
  }

  @override
  int getHighlightCircleStrokeAlpha() {
    return _highlightCircleStrokeAlpha;
  }

  void setHighlightCircleStrokeAlpha(int alpha) {
    _highlightCircleStrokeAlpha = alpha;
  }

  @override
  double getHighlightCircleInnerRadius() {
    return _highlightCircleInnerRadius;
  }

  void setHighlightCircleInnerRadius(double radius) {
    _highlightCircleInnerRadius = radius;
  }

  @override
  double getHighlightCircleOuterRadius() {
    return _highlightCircleOuterRadius;
  }

  void setHighlightCircleOuterRadius(double radius) {
    _highlightCircleOuterRadius = radius;
  }

  @override
  double getHighlightCircleStrokeWidth() {
    return _highlightCircleStrokeWidth;
  }

  void setHighlightCircleStrokeWidth(double strokeWidth) {
    _highlightCircleStrokeWidth = strokeWidth;
  }

  @override
  DataSet<RadarEntry> copy1() {
    List<RadarEntry> entries = List<RadarEntry>();
    for (int i = 0; i < values.length; i++) {
      entries.add(values[i].copy());
    }
    RadarDataSet copied = RadarDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is RadarDataSet) {
      var radarDataSet = baseDataSet;
      radarDataSet._drawHighlightCircleEnabled = _drawHighlightCircleEnabled;
      radarDataSet._highlightCircleFillColor = _highlightCircleFillColor;
      radarDataSet._highlightCircleInnerRadius = _highlightCircleInnerRadius;
      radarDataSet._highlightCircleStrokeAlpha = _highlightCircleStrokeAlpha;
      radarDataSet._highlightCircleStrokeColor = _highlightCircleStrokeColor;
      radarDataSet._highlightCircleStrokeWidth = _highlightCircleStrokeWidth;
    }
  }
}
