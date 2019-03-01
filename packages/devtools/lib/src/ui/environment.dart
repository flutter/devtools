import 'dart:html';

import 'package:meta/meta.dart';

num get devicePixelRatio => _devicePixelRatio;

num _devicePixelRatio = window.devicePixelRatio;

@visibleForTesting
void overrideDevicePixelRatio(num value) {
  _devicePixelRatio = value;
}
