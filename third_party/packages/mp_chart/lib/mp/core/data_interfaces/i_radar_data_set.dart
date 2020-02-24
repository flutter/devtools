import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_line_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/radar_entry.dart';

mixin IRadarDataSet implements ILineRadarDataSet<RadarEntry> {
  /// flag indicating whether highlight circle should be drawn or not
  bool isDrawHighlightCircleEnabled();

  /// Sets whether highlight circle should be drawn or not
  void setDrawHighlightCircleEnabled(bool enabled);

  Color getHighlightCircleFillColor();

  /// The stroke color for highlight circle.
  /// If Utils.COLOR_NONE, the color of the dataset is taken.
  Color getHighlightCircleStrokeColor();

  int getHighlightCircleStrokeAlpha();

  double getHighlightCircleInnerRadius();

  double getHighlightCircleOuterRadius();

  double getHighlightCircleStrokeWidth();
}
