import 'package:mp_chart/mp/controller/bar_line_scatter_candle_bubble_controller.dart';
import 'package:mp_chart/mp/controller/controller.dart';
import 'package:mp_chart/mp/controller/radar_chart_controller.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/legend/legend.dart';
import 'package:mp_chart/mp/core/render/data_renderer.dart';

typedef XAxisSettingFunction = void Function(
    XAxis xAxis, Controller controller);
typedef LegendSettingFunction = void Function(
    Legend legend, Controller controller);
typedef YAxisSettingFunction = void Function(
    YAxis yAxis, RadarChartController controller);
typedef AxisLeftSettingFunction = void Function(
    YAxis axisLeft, BarLineScatterCandleBubbleController controller);
typedef AxisRightSettingFunction = void Function(
    YAxis axisRight, BarLineScatterCandleBubbleController controller);
typedef DataRendererSettingFunction = void Function(DataRenderer renderer);
