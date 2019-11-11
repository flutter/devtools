import 'package:mp_chart/mp/core/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_scatter_data_set.dart';

class ScatterData extends BarLineScatterCandleBubbleData<IScatterDataSet> {
  ScatterData() : super();

  ScatterData.fromList(List<IScatterDataSet> dataSets)
      : super.fromList(dataSets);

  /// Returns the maximum shape-size across all DataSets.
  ///
  /// @return
  double getGreatestShapeSize() {
    double max = 0;

    for (IScatterDataSet set in dataSets) {
      double size = set.getScatterShapeSize();

      if (size > max) max = size;
    }

    return max;
  }
}
