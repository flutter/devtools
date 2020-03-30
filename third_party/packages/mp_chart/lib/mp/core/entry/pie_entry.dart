import 'package:mp_chart/mp/core/entry/entry.dart';
import 'dart:ui' as ui;

class PieEntry extends Entry {
  String _label;

  PieEntry({double value, String label, ui.Image icon, Object data})
      : super(x: 0, y: value, icon: icon, data: data) {
    this._label = label;
  }

  double getValue() {
    return y;
  }

  PieEntry copy() {
    PieEntry e = PieEntry(value: getValue(), label: _label, data: mData);
    return e;
  }

  // ignore: unnecessary_getters_setters
  String get label => _label;

  // ignore: unnecessary_getters_setters
  set label(String value) {
    _label = value;
  }
}
