import 'package:mp_chart/mp/core/data/bar_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/bar_data_provider.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/rounding.dart';
import 'package:mp_chart/mp/core/highlight/bar_highlighter.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';

class HorizontalBarHighlighter extends BarHighlighter {
  HorizontalBarHighlighter(BarDataProvider chart) : super(chart);

  @override
  Highlight getHighlight(double x, double y) {
    BarData barData = provider.getBarData();

    MPPointD pos = getValsForTouch(y, x);

    Highlight high = getHighlightForX(pos.y, y, x);
    if (high == null) return null;

    IBarDataSet set = barData.getDataSetByIndex(high.dataSetIndex);
    if (set.isStacked()) {
      return getStackedHighlight(high, set, pos.y, pos.x);
    }

    MPPointD.recycleInstance2(pos);

    return high;
  }

  @override
  List<Highlight> buildHighlights(
      IDataSet set, int dataSetIndex, double xVal, Rounding rounding) {
    List<Highlight> highlights = List();

    //noinspection unchecked
    List<Entry> entries = set.getEntriesForXValue(xVal);
    if (entries.length == 0) {
      // Try to find closest x-value and take all entries for that x-value
      final Entry closest = set.getEntryForXValue1(xVal, double.nan, rounding);
      if (closest != null) {
        //noinspection unchecked
        entries = set.getEntriesForXValue(closest.x);
      }
    }

    if (entries.length == 0) return highlights;

    for (Entry e in entries) {
      MPPointD pixels = provider
          .getTransformer(set.getAxisDependency())
          .getPixelForValues(e.y, e.x);

      highlights.add(Highlight(
          x: e.x,
          y: e.y,
          xPx: pixels.x,
          yPx: pixels.y,
          dataSetIndex: dataSetIndex,
          axis: set.getAxisDependency()));
    }

    return highlights;
  }

  @override
  double getDistance(double x1, double y1, double x2, double y2) {
    return (y1 - y2).abs();
  }
}
