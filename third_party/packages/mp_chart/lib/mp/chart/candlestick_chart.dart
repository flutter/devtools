import 'package:mp_chart/mp/chart/bar_line_scatter_candle_bubble_chart.dart';
import 'package:mp_chart/mp/controller/candlestick_chart_controller.dart';

class CandlestickChart
    extends BarLineScatterCandleBubbleChart<CandlestickChartController> {
  const CandlestickChart(CandlestickChartController controller)
      : super(controller);
}

class CandlestickChartState
    extends BarLineScatterCandleBubbleState<CandlestickChart> {}
