import 'package:mp_chart/mp/core/data_interfaces/i_line_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/line_data_provider.dart';

mixin IFillFormatter {
  double getFillLinePosition(
      ILineDataSet dataSet, LineDataProvider dataProvider);
}
