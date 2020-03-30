import 'dart:ui';

import 'package:mp_chart/mp/core/data_interfaces/i_bar_line_scatter_candle_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/data_set/data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';

abstract class BarLineScatterCandleBubbleDataSet<T extends Entry>
    extends DataSet<T> implements IBarLineScatterCandleBubbleDataSet<T> {
  Color _highLightColor = Color.fromARGB(255, 255, 187, 115);

  BarLineScatterCandleBubbleDataSet(List<T> yVals, String label)
      : super(yVals, label);

  /// Sets the color that is used for drawing the highlight indicators. Dont
  /// forget to resolve the color using getResources().getColor(...) or
  /// Color.rgb(...).
  ///
  /// @param color
  void setHighLightColor(Color color) {
    _highLightColor = color;
  }

  @override
  Color getHighLightColor() {
    return _highLightColor;
  }

  @override
  void copy(BaseDataSet baseDataSet) {
    super.copy(baseDataSet);
    if (baseDataSet is BarLineScatterCandleBubbleDataSet) {
      var barLineScatterCandleBubbleDataSet = baseDataSet;
      barLineScatterCandleBubbleDataSet._highLightColor = _highLightColor;
    }
  }

  @override
  String toString() {
    return '${super.toString()}\nBarLineScatterCandleBubbleDataSet{_highLightColor: $_highLightColor}';
  }
}
