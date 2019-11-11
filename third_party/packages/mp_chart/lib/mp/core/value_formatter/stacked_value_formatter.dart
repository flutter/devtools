import 'package:intl/intl.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

class StackedValueFormatter extends ValueFormatter {
  /// if true, all stack values of the stacked bar entry are drawn, else only top
  bool _drawWholeStack;

  /// a string that should be appended behind the value
  String _suffix;

  NumberFormat _format;

  /// Constructor.
  ///
  /// @param drawWholeStack if true, all stack values of the stacked bar entry are drawn, else only top
  /// @param suffix         a string that should be appended behind the value
  /// @param decimals       the number of decimal digits to use
  StackedValueFormatter(bool drawWholeStack, String suffix, int decimals) {
    this._drawWholeStack = drawWholeStack;
    this._suffix = suffix;

    StringBuffer b = new StringBuffer();
    for (int i = 0; i < decimals; i++) {
      if (i == 0) b.write(".");
      b.write("0");
    }

    this._format = NumberFormat("###,###,###,##0" + b.toString());
  }

  @override
  String getBarStackedLabel(double value, BarEntry entry) {
    if (!_drawWholeStack) {
      List<double> vals = entry.yVals;

      if (vals != null) {
        // find out if we are on top of the stack
        if (vals[vals.length - 1] == value) {
          // return the "sum" across all stack values
          return _format.format(entry.y) + _suffix;
        } else {
          return ""; // return empty
        }
      }
    }
    // return the "proposed" value
    return _format.format(value) + _suffix;
  }
}
