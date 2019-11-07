import 'package:mp_chart/mp/core/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_candle_data_set.dart';

class CandleData extends BarLineScatterCandleBubbleData<ICandleDataSet> {
  CandleData() : super();

  CandleData.fromList(List<ICandleDataSet> dataSets) : super.fromList(dataSets);
}
