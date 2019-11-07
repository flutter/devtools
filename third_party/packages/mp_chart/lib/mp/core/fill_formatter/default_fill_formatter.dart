import 'package:mp_chart/mp/core/data/line_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_line_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/line_data_provider.dart';
import 'package:mp_chart/mp/core/fill_formatter/i_fill_formatter.dart';

class DefaultFillFormatter implements IFillFormatter {
  @override
  double getFillLinePosition(
      ILineDataSet dataSet, LineDataProvider dataProvider) {
    double fillMin = 0;
    double chartMaxY = dataProvider.getYChartMax();
    double chartMinY = dataProvider.getYChartMin();

    LineData data = dataProvider.getLineData();

    if (dataSet.getYMax() > 0 && dataSet.getYMin() < 0) {
      fillMin = 0;
    } else {
      double max, min;

      if (data.getYMax1() > 0)
        max = 0;
      else
        max = chartMaxY;
      if (data.getYMin1() < 0)
        min = 0;
      else
        min = chartMinY;

      fillMin = dataSet.getYMin() >= 0 ? min : max;
    }
    return fillMin;
  }
}
