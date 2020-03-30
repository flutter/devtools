import 'package:mp_chart/mp/chart/pie_radar_chart.dart';
import 'package:mp_chart/mp/controller/radar_chart_controller.dart';

class RadarChart extends PieRadarChart<RadarChartController> {
  const RadarChart(RadarChartController controller) : super(controller);
}

class RadarChartState extends PieRadarChartState<RadarChart> {}
