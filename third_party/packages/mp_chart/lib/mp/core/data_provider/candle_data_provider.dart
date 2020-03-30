import 'package:mp_chart/mp/core/data/candle_data.dart';
import 'package:mp_chart/mp/core/data_provider/bar_line_scatter_candle_bubble_data_provider.dart';

mixin CandleDataProvider implements BarLineScatterCandleBubbleDataProvider {
  CandleData getCandleData();
}
