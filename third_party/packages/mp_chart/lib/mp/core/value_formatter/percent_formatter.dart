import 'package:intl/intl.dart';
import 'package:mp_chart/mp/controller/pie_chart_controller.dart';
import 'package:mp_chart/mp/core/entry/pie_entry.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

class PercentFormatter extends ValueFormatter {
  NumberFormat _format;
  PieChartController _controller;
  bool _percentSignSeparated;

  PercentFormatter() {
    _format = NumberFormat("###,###,##0.0");
    _percentSignSeparated = true;
  }

  setPieChartPainter(PieChartController controller) {
    _controller = controller;
  }

  @override
  String getFormattedValue1(double value) {
    return _format.format(value) + (_percentSignSeparated ? " %" : "%");
  }

  @override
  String getPieLabel(double value, PieEntry pieEntry) {
    if (_controller != null &&
        _controller.painter != null &&
        _controller.painter.isUsePercentValuesEnabled()) {
      // Converted to percent
      return getFormattedValue1(value);
    } else {
      // raw value, skip percent sign
      return _format.format(value);
    }
  }
}
