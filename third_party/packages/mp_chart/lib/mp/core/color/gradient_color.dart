import 'dart:ui';

class GradientColor {
  Color _startColor;
  Color _endColor;

  GradientColor(this._startColor, this._endColor);

  // ignore: unnecessary_getters_setters
  Color get endColor => _endColor;

  // ignore: unnecessary_getters_setters
  set endColor(Color value) {
    _endColor = value;
  }

  // ignore: unnecessary_getters_setters
  Color get startColor => _startColor;

  // ignore: unnecessary_getters_setters
  set startColor(Color value) {
    _startColor = value;
  }
}
