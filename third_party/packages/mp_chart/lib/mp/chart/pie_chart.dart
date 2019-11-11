import 'package:mp_chart/mp/chart/pie_radar_chart.dart';
import 'package:mp_chart/mp/controller/pie_chart_controller.dart';

class PieChart extends PieRadarChart<PieChartController> {
  const PieChart(PieChartController controller) : super(controller);
}

class PieChartState extends PieRadarChartState<PieChart> {}
