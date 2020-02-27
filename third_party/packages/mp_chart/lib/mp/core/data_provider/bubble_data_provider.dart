import 'package:mp_chart/mp/core/data/bubble_data.dart';
import 'package:mp_chart/mp/core/data_provider/bar_line_scatter_candle_bubble_data_provider.dart';

mixin BubbleDataProvider implements BarLineScatterCandleBubbleDataProvider {
  BubbleData getBubbleData();
}
