import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_bar_line_scatter_candle_bubble_data_set.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';

mixin IBarDataSet implements IBarLineScatterCandleBubbleDataSet<BarEntry> {
  /// Returns true if this DataSet is stacked (stacksize > 1) or not.
  ///
  /// @return
  bool isStacked();

  /// Returns the maximum number of bars that can be stacked upon another in
  /// this DataSet. This should return 1 for non stacked bars, and > 1 for stacked bars.
  ///
  /// @return
  int getStackSize();

  /// Returns the color used for drawing the bar-shadows. The bar shadows is a
  /// surface behind the bar that indicates the maximum value.
  ///
  /// @return
  Color getBarShadowColor();

  /// Returns the width used for drawing borders around the bars.
  /// If borderWidth == 0, no border will be drawn.
  ///
  /// @return
  double getBarBorderWidth();

  /// Returns the color drawing borders around the bars.
  ///
  /// @return
  Color getBarBorderColor();

  /// Returns the alpha value (transparency) that is used for drawing the
  /// highlight indicator.
  ///
  /// @return
  int getHighLightAlpha();

  /// Returns the labels used for the different value-stacks in the legend.
  /// This is only relevant for stacked bar entries.
  ///
  /// @return
  List<String> getStackLabels();
}
