import 'dart:ui' as ui;

abstract class BaseEntry {
  /// the y value
  double _y = 0;

  /// optional spot for additional data this Entry represents
  Object _data;

  /// optional icon image
  ui.Image _icon;

  BaseEntry({double y, ui.Image icon, Object data}) {
    this._y = y;
    this._icon = icon;
    this._data = data;
  }

  ui.Image get mIcon => _icon;

  set mIcon(ui.Image value) {
    _icon = value;
  }

  Object get mData => _data;

  set mData(Object value) {
    _data = value;
  }

  double get y => _y;

  set y(double value) {
    _y = value;
  }
}
