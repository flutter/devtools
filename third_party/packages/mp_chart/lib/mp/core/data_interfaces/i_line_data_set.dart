import 'dart:ui';

import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_line_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/mode.dart';
import 'package:mp_chart/mp/core/fill_formatter/i_fill_formatter.dart';

mixin ILineDataSet implements ILineRadarDataSet<Entry> {
  /// Returns the drawing mode for this line dataset
  ///
  /// @return
  Mode getMode();

  /// Returns the intensity of the cubic lines (the effect intensity).
  /// Max = 1f = very cubic, Min = 0.05f = low cubic effect, Default: 0.2f
  ///
  /// @return
  double getCubicIntensity();

  bool isDrawCubicEnabled();

  bool isDrawSteppedEnabled();

  /// Returns the size of the drawn circles.
  double getCircleRadius();

  /// Returns the hole radius of the drawn circles.
  double getCircleHoleRadius();

  /// Returns the color at the given index of the DataSet's circle-color array.
  /// Performs a IndexOutOfBounds check by modulus.
  ///
  /// @param index
  /// @return
  Color getCircleColor(int index);

  /// Returns the number of colors in this DataSet's circle-color array.
  ///
  /// @return
  int getCircleColorCount();

  /// Returns true if drawing circles for this DataSet is enabled, false if not
  ///
  /// @return
  bool isDrawCirclesEnabled();

  /// Returns the color of the inner circle (the circle-hole).
  ///
  /// @return
  Color getCircleHoleColor();

  /// Returns true if drawing the circle-holes is enabled, false if not.
  ///
  /// @return
  bool isDrawCircleHoleEnabled();

  /// Returns the DashPathEffect that is used for drawing the lines.
  ///
  /// @return
  DashPathEffect getDashPathEffect();

  /// Returns true if the dashed-line effect is enabled, false if not.
  /// If the DashPathEffect object is null, also return false here.
  ///
  /// @return
  bool isDashedLineEnabled();

  /// Returns the IFillFormatter that is set for this DataSet.
  ///
  /// @return
  IFillFormatter getFillFormatter();
}
