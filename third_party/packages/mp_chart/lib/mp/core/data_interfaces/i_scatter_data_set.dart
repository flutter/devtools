import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_line_scatter_candle_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/render/i_shape_renderer.dart';

mixin IScatterDataSet implements ILineScatterCandleRadarDataSet<Entry> {
  /// Returns the currently set scatter shape size
  ///
  /// @return
  double getScatterShapeSize();

  /// Returns radius of the hole in the shape
  ///
  /// @return
  double getScatterShapeHoleRadius();

  /// Returns the color for the hole in the shape
  ///
  /// @return
  Color getScatterShapeHoleColor();

  /// Returns the IShapeRenderer responsible for rendering this DataSet.
  ///
  /// @return
  IShapeRenderer getShapeRenderer();
}
