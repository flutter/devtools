import 'package:mp_chart/mp/chart/bar_line_scatter_candle_bubble_chart.dart';
import 'package:mp_chart/mp/controller/scatter_chart_controller.dart';

class ScatterChart
    extends BarLineScatterCandleBubbleChart<ScatterChartController> {
  const ScatterChart(ScatterChartController controller) : super(controller);
}

class ScatterChartState extends BarLineScatterCandleBubbleState<ScatterChart> {}
