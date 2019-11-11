import 'package:intl/intl.dart';
import 'package:mp_chart/mp/core/axis/axis_base.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

class MyValueFormatter extends ValueFormatter {
  NumberFormat _format;
  String _suffix;

  MyValueFormatter(String suffix) {
    _format = NumberFormat("###,###,###,##0.0");
    this._suffix = suffix;
  }

  @override
  String getFormattedValue1(double value) {
    return _format.format(value) + _suffix;
  }

  @override
  String getAxisLabel(double value, AxisBase axis) {
    if (axis is XAxis) {
      return _format.format(value);
    } else if (value > 0) {
      return _format.format(value) + _suffix;
    } else {
      return _format.format(value);
    }
  }
}
