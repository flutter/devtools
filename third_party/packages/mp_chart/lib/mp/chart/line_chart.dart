import 'package:mp_chart/mp/chart/bar_line_scatter_candle_bubble_chart.dart';
import 'package:mp_chart/mp/controller/line_chart_controller.dart';

class LineChart extends BarLineScatterCandleBubbleChart<LineChartController> {
  const LineChart(LineChartController controller) : super(controller);
}

class LineChartState extends BarLineScatterCandleBubbleState<LineChart> {}
