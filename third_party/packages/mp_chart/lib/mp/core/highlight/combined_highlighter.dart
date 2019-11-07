import 'package:mp_chart/mp/core/data/bar_data.dart';
import 'package:mp_chart/mp/core/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_chart/mp/core/data/chart_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/bar_data_provider.dart';
import 'package:mp_chart/mp/core/data_provider/combined_data_provider.dart';
import 'package:mp_chart/mp/core/enums/rounding.dart';
import 'package:mp_chart/mp/core/highlight/bar_highlighter.dart';
import 'package:mp_chart/mp/core/highlight/chart_hightlighter.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/highlight/i_highlighter.dart';

class CombinedHighlighter extends ChartHighlighter<CombinedDataProvider>
    implements IHighlighter {
  /// bar highlighter for supporting stacked highlighting
  BarHighlighter _barHighlighter;

  CombinedHighlighter(CombinedDataProvider chart, BarDataProvider barChart)
      : super(chart) {
    // if there is BarData, create a BarHighlighter
    _barHighlighter =
        barChart.getBarData() == null ? null : BarHighlighter(barChart);
  }

  @override
  List<Highlight> getHighlightsAtXValue(double xVal, double x, double y) {
    highlightBuffer.clear();

    List<BarLineScatterCandleBubbleData> dataObjects =
        provider.getCombinedData().getAllData();

    for (int i = 0; i < dataObjects.length; i++) {
      ChartData dataObject = dataObjects[i];

      // in case of BarData, let the BarHighlighter take over
      if (_barHighlighter != null && dataObject is BarData) {
        Highlight high = _barHighlighter.getHighlight(x, y);

        if (high != null) {
          high.dataIndex = (i);
          highlightBuffer.add(high);
        }
      } else {
        for (int j = 0, dataSetCount = dataObject.getDataSetCount();
            j < dataSetCount;
            j++) {
          IDataSet dataSet = dataObjects[i].getDataSetByIndex(j);

          // don't include datasets that cannot be highlighted
          if (!dataSet.isHighlightEnabled()) continue;

          List<Highlight> highs =
              buildHighlights(dataSet, j, xVal, Rounding.CLOSEST);
          for (Highlight high in highs) {
            high.dataIndex = (i);
            highlightBuffer.add(high);
          }
        }
      }
    }

    return highlightBuffer;
  }
}
