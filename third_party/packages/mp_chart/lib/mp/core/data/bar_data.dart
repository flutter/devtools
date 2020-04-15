import 'package:mp_chart/mp/core/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';

class BarData extends BarLineScatterCandleBubbleData<IBarDataSet> {
  /// the width of the bars on the x-axis, in values (not pixels)
  double _barWidth = 0.85;

  BarData(List<IBarDataSet> dataSets) : super.fromList(dataSets);

  // ignore: unnecessary_getters_setters
  double get barWidth => _barWidth;

  // ignore: unnecessary_getters_setters
  set barWidth(double value) {
    _barWidth = value;
  }

  /// Groups all BarDataSet objects this data object holds together by modifying the x-value of their entries.
  /// Previously set x-values of entries will be overwritten. Leaves space between bars and groups as specified
  /// by the parameters.
  /// Do not forget to call notifyDataSetChanged() on your BarChart object after calling this method.
  ///
  /// @param fromX      the starting point on the x-axis where the grouping should begin
  /// @param groupSpace the space between groups of bars in values (not pixels) e.g. 0.8f for bar width 1f
  /// @param barSpace   the space between individual bars in values (not pixels) e.g. 0.1f for bar width 1f
  void groupBars(double fromX, double groupSpace, double barSpace) {
    int setCount = dataSets.length;
    if (setCount <= 1) {
      throw Exception(
          "BarData needs to hold at least 2 BarDataSets to allow grouping.");
    }

    IBarDataSet max = getMaxEntryCountSet();
    int maxEntryCount = max.getEntryCount();

    double groupSpaceWidthHalf = groupSpace / 2.0;
    double barSpaceHalf = barSpace / 2.0;
    double barWidthHalf = _barWidth / 2.0;

    double interval = getGroupWidth(groupSpace, barSpace);

    for (int i = 0; i < maxEntryCount; i++) {
      double start = fromX;
      fromX += groupSpaceWidthHalf;

      for (IBarDataSet set in dataSets) {
        fromX += barSpaceHalf;
        fromX += barWidthHalf;

        if (i < set.getEntryCount()) {
          BarEntry entry = set.getEntryForIndex(i);

          if (entry != null) {
            entry.x = fromX;
          }
        }

        fromX += barWidthHalf;
        fromX += barSpaceHalf;
      }

      fromX += groupSpaceWidthHalf;
      double end = fromX;
      double innerInterval = end - start;
      double diff = interval - innerInterval;

      // correct rounding errors
      if (diff > 0 || diff < 0) {
        fromX += diff;
      }
    }

    notifyDataChanged();
  }

  /// In case of grouped bars, this method returns the space an individual group of bar needs on the x-axis.
  ///
  /// @param groupSpace
  /// @param barSpace
  /// @return
  double getGroupWidth(double groupSpace, double barSpace) {
    return dataSets.length * (_barWidth + barSpace) + groupSpace;
  }
}
