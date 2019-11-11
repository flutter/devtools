import 'package:mp_chart/mp/chart/bar_line_scatter_candle_bubble_chart.dart';
import 'package:mp_chart/mp/controller/bar_chart_controller.dart';

class BarChart extends BarLineScatterCandleBubbleChart<BarChartController> {
  const BarChart(BarChartController controller) : super(controller);
}

class BarChartState extends BarLineScatterCandleBubbleState<BarChart> {}
