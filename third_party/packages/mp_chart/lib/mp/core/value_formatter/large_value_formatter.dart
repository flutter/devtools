import 'package:intl/intl.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

class LargeValueFormatter extends ValueFormatter {
  List<String> _suffix = List()
    ..add("")
    ..add("k")
    ..add("m")
    ..add("b")
    ..add("t");
  int _maxLength = 5;
  NumberFormat _format;
  String _text = "";

  /// Creates a formatter that appends a specified text to the result string
  ///
  /// @param appendix a text that will be appended
  LargeValueFormatter({String appendix = ""}) {
    _format = new NumberFormat("###E00");
    _text = appendix;
  }

  @override
  String getFormattedValue1(double value) {
    return makePretty(value) + _text;
  }

  /// Set an appendix text to be added at the end of the formatted value.
  ///
  /// @param appendix
  void setAppendix(String appendix) {
    this._text = appendix;
  }

  /// Set custom suffix to be appended after the values.
  /// Default suffix: ["", "k", "m", "b", "t"]
  ///
  /// @param suffix new suffix
  void setSuffix(List<String> suffix) {
    this._suffix = suffix;
  }

  void setMaxLength(int maxLength) {
    this._maxLength = maxLength;
  }

  /// Formats each number properly. Special thanks to Roman Gromov
  /// (https://github.com/romangromov) for this piece of code.
  String makePretty(double number) {
    String r = _format.format(number);
    int numericValue1 = int.tryParse(r[r.length - 1]);
    int numericValue2 = int.tryParse(r[r.length - 2]);
    int combined = int.parse("$numericValue2$numericValue1");

    r = r.replaceAllMapped(
        RegExp(
          r"E[0-9][0-9]",
          caseSensitive: false,
          multiLine: false,
        ),
        (match) => _suffix[combined ~/ 3]);

    while (r.length > _maxLength ||
        RegExp(
          r"[0-9]+\\.[a-z]",
          caseSensitive: false,
          multiLine: false,
        ).hasMatch(r)) {
      r = r.substring(0, r.length - 2) + r.substring(r.length - 1);
    }

    return r;
  }

  int getDecimalDigits() {
    return 0;
  }
}
