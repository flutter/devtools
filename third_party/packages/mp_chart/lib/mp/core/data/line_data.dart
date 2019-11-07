import 'package:mp_chart/mp/core/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_line_data_set.dart';

class LineData extends BarLineScatterCandleBubbleData<ILineDataSet> {
  LineData() : super();

  LineData.fromList(List<ILineDataSet> sets) : super.fromList(sets);
}
