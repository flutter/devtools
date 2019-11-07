import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/data_set/bar_line_scatter_candle_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/data_set.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';

class BarDataSet extends BarLineScatterCandleBubbleDataSet<BarEntry>
    implements IBarDataSet {
  /// the maximum number of bars that are stacked upon each other, this value
  /// is calculated from the Entries that are added to the DataSet
  int _stackSize = 1;

  /// the color used for drawing the bar shadows
  Color _barShadowColor = Color.fromARGB(255, 215, 215, 215);

  double _barBorderWidth = 0.0;

  Color _barBorderColor = ColorUtils.BLACK;

  /// the alpha value used to draw the highlight indicator bar
  int _highLightAlpha = 120;

  /// the overall entry count, including counting each stack-value individually
  int _entryCountStacks = 0;

  /// array of labels used to describe the different values of the stacked bars
  List<String> _stackLabels = List()..add("Stack");

  BarDataSet(List<BarEntry> yVals, String label) : super(yVals, label) {
    setHighLightColor(Color.fromARGB(255, 0, 0, 0));
    calcStackSize(yVals);
    calcEntryCountIncludingStacks(yVals);
  }

  @override
  DataSet<BarEntry> copy1() {
    List<BarEntry> entries = List();
    for (int i = 0; i < values.length; i++) {
      entries.add(values[i].copy());
    }
    BarDataSet copied = BarDataSet(entries, getLabel());
    copy(copied);
    return copied;
  }

  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is BarDataSet) {
      var barDataSet = baseDataSet;
      barDataSet._stackSize = _stackSize;
      barDataSet._barShadowColor = _barShadowColor;
      barDataSet._barBorderWidth = _barBorderWidth;
      barDataSet._stackLabels = _stackLabels;
      barDataSet._highLightAlpha = _highLightAlpha;
    }
  }

  /// Calculates the total number of entries this DataSet represents, including
  /// stacks. All values belonging to a stack are calculated separately.
  void calcEntryCountIncludingStacks(List<BarEntry> yVals) {
    _entryCountStacks = 0;

    for (int i = 0; i < yVals.length; i++) {
      List<double> vals = yVals[i].yVals;

      if (vals == null)
        _entryCountStacks++;
      else
        _entryCountStacks += vals.length;
    }
  }

  /// calculates the maximum stacksize that occurs in the Entries array of this
  /// DataSet
  void calcStackSize(List<BarEntry> yVals) {
    for (int i = 0; i < yVals.length; i++) {
      List<double> vals = yVals[i].yVals;

      if (vals != null && vals.length > _stackSize) _stackSize = vals.length;
    }
  }

  @override
  void calcMinMax1(BarEntry e) {
    if (e != null && !e.y.isNaN) {
      if (e.yVals == null) {
        if (e.y < getYMin()) yMin = e.y;

        if (e.y > getYMax()) yMax = e.y;
      } else {
        if (-e.negativeSum < getYMin()) yMin = -e.negativeSum;

        if (e.positiveSum > getYMax()) yMax = e.positiveSum;
      }

      calcMinMaxX1(e);
    }
  }

  @override
  int getStackSize() {
    return _stackSize;
  }

  @override
  bool isStacked() {
    return _stackSize > 1 ? true : false;
  }

  /// returns the overall entry count, including counting each stack-value
  /// individually
  ///
  /// @return
  int getEntryCountStacks() {
    return _entryCountStacks;
  }

  /// Sets the color used for drawing the bar-shadows. The bar shadows is a
  /// surface behind the bar that indicates the maximum value. Don't for get to
  /// use getResources().getColor(...) to set this. Or Color.rgb(...).
  ///
  /// @param color
  void setBarShadowColor(Color color) {
    _barShadowColor = color;
  }

  @override
  Color getBarShadowColor() {
    return _barShadowColor;
  }

  /// Sets the width used for drawing borders around the bars.
  /// If borderWidth == 0, no border will be drawn.
  ///
  /// @return
  void setBarBorderWidth(double width) {
    _barBorderWidth = width;
  }

  /// Returns the width used for drawing borders around the bars.
  /// If borderWidth == 0, no border will be drawn.
  ///
  /// @return
  @override
  double getBarBorderWidth() {
    return _barBorderWidth;
  }

  /// Sets the color drawing borders around the bars.
  ///
  /// @return
  void setBarBorderColor(Color color) {
    _barBorderColor = color;
  }

  /// Returns the color drawing borders around the bars.
  ///
  /// @return
  @override
  Color getBarBorderColor() {
    return _barBorderColor;
  }

  /// Set the alpha value (transparency) that is used for drawing the highlight
  /// indicator bar. min = 0 (fully transparent), max = 255 (fully opaque)
  ///
  /// @param alpha
  void setHighLightAlpha(int alpha) {
    _highLightAlpha = alpha;
  }

  @override
  int getHighLightAlpha() {
    return _highLightAlpha;
  }

  /// Sets labels for different values of bar-stacks, in case there are one.
  ///
  /// @param labels
  void setStackLabels(List<String> labels) {
    _stackLabels = labels;
  }

  @override
  List<String> getStackLabels() {
    return _stackLabels;
  }
}
