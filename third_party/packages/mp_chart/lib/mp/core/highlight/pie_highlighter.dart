import 'package:mp_chart/mp/core/data/pie_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_pie_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/highlight/pie_radar_highlighter.dart';
import 'package:mp_chart/mp/painter/pie_chart_painter.dart';

class PieHighlighter extends PieRadarHighlighter<PieChartPainter> {
  PieHighlighter(PieChartPainter chart) : super(chart);

  @override
  Highlight getClosestHighlight(int index, double x, double y) {
    IPieDataSet set = (painter.getData() as PieData).getDataSet();

    final Entry entry = set.getEntryForIndex(index);

    return new Highlight(
        x: index.toDouble(),
        y: entry.y,
        xPx: x,
        yPx: y,
        dataSetIndex: 0,
        axis: set.getAxisDependency());
  }
}
