import 'package:mp_chart/mp/core/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bubble_data_set.dart';

class BubbleData extends BarLineScatterCandleBubbleData<IBubbleDataSet> {
  BubbleData() : super();

  BubbleData.fromList(List<IBubbleDataSet> dataSets) : super.fromList(dataSets);

  /// Sets the width of the circle that surrounds the bubble when highlighted
  /// for all DataSet objects this data object contains, in dp.
  ///
  /// @param width
  void setHighlightCircleWidth(double width) {
    for (IBubbleDataSet set in dataSets) {
      set.setHighlightCircleWidth(width);
    }
  }
}
