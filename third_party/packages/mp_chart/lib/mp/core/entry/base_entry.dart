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

  // ignore: unnecessary_getters_setters
  ui.Image get mIcon => _icon;

  // ignore: unnecessary_getters_setters
  set mIcon(ui.Image value) {
    _icon = value;
  }

  // ignore: unnecessary_getters_setters
  Object get mData => _data;

  // ignore: unnecessary_getters_setters
  set mData(Object value) {
    _data = value;
  }

  // ignore: unnecessary_getters_setters
  double get y => _y;

  // ignore: unnecessary_getters_setters
  set y(double value) {
    _y = value;
  }
}
