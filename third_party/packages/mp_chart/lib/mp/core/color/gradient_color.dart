import 'dart:ui';

class GradientColor {
  Color _startColor;
  Color _endColor;

  GradientColor(this._startColor, this._endColor);

  Color get endColor => _endColor;

  set endColor(Color value) {
    _endColor = value;
  }

  Color get startColor => _startColor;

  set startColor(Color value) {
    _startColor = value;
  }
}
