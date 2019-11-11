import 'package:mp_chart/mp/core/entry/entry.dart';
import 'dart:ui' as ui;

class CandleEntry extends Entry {
  /// shadow-high value
  double _shadowHigh = 0;

  /// shadow-low value
  double _shadowLow = 0;

  /// close value
  double _close = 0;

  /// open value
  double _open = 0;

  CandleEntry(
      {double x,
      double shadowH,
      double shadowL,
      double open,
      double close,
      ui.Image icon,
      Object data})
      : super(x: x, y: (shadowH + shadowL) / 2, icon: icon, data: data) {
    this._shadowHigh = shadowH;
    this._shadowLow = shadowL;
    this._open = open;
    this._close = close;
  }

  /// Returns the overall range (difference) between shadow-high and
  /// shadow-low.
  ///
  /// @return
  double getShadowRange() {
    return (_shadowHigh - _shadowLow).abs();
  }

  /// Returns the body size (difference between open and close).
  ///
  /// @return
  double getBodyRange() {
    return (_open - _close).abs();
  }

  CandleEntry copy() {
    CandleEntry c = CandleEntry(
        x: x,
        shadowH: _shadowHigh,
        shadowL: _shadowLow,
        open: _open,
        close: _close,
        data: mData);
    return c;
  }

  double get open => _open;

  set open(double value) {
    _open = value;
  }

  double get close => _close;

  set close(double value) {
    _close = value;
  }

  double get shadowLow => _shadowLow;

  set shadowLow(double value) {
    _shadowLow = value;
  }

  double get shadowHigh => _shadowHigh;

  set shadowHigh(double value) {
    _shadowHigh = value;
  }
}
