import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/entry/pie_entry.dart';
import 'package:mp_chart/mp/core/enums/value_position.dart';

mixin IPieDataSet implements IDataSet<PieEntry> {
  /// Returns the space that is set to be between the piechart-slices of this
  /// DataSet, in pixels.
  ///
  /// @return
  double getSliceSpace();

  /// When enabled, slice spacing will be 0.0 when the smallest value is going to be
  ///   smaller than the slice spacing itself.
  ///
  /// @return
  bool isAutomaticallyDisableSliceSpacingEnabled();

  /// Returns the distance a highlighted piechart slice is "shifted" away from
  /// the chart-center in dp.
  ///
  /// @return
  double getSelectionShift();

  ValuePosition getXValuePosition();

  ValuePosition getYValuePosition();

  /// When valuePosition is OutsideSlice, use slice colors as line color if true
  /// */
  bool isUsingSliceColorAsValueLineColor();

  /// When valuePosition is OutsideSlice, indicates line color
  /// */
  Color getValueLineColor();

  ///  When valuePosition is OutsideSlice, indicates line width
  ///  */
  double getValueLineWidth();

  /// When valuePosition is OutsideSlice, indicates offset as percentage out of the slice size
  /// */
  double getValueLinePart1OffsetPercentage();

  /// When valuePosition is OutsideSlice, indicates length of first half of the line
  /// */
  double getValueLinePart1Length();

  /// When valuePosition is OutsideSlice, indicates length of second half of the line
  /// */
  double getValueLinePart2Length();

  /// When valuePosition is OutsideSlice, this allows variable line length
  /// */
  bool isValueLineVariableLength();
}
