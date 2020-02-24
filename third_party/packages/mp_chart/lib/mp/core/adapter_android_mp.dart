import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

class DashPathEffect {
  CircularIntervalList<double> _circularIntervalList;

  DashOffset _dashOffset;

  CircularIntervalList<double> get circularIntervalList =>
      _circularIntervalList;

  DashPathEffect(double lineLength, double spaceLength, double value)
      : _circularIntervalList =
            CircularIntervalList<double>(<double>[lineLength, spaceLength]),
        _dashOffset = DashOffset.absolute(value);

  Path convert2DashPath(Path path) {
    if (_circularIntervalList == null) {
      return path;
    }
    return dashPath(path,
        dashArray: _circularIntervalList, dashOffset: _dashOffset);
  }

  @override
  String toString() {
    return 'DashPathEffect{_circularIntervalList: $_circularIntervalList,\n _dashOffset: $_dashOffset}';
  }
}

class TypeFace {
  String _fontFamily;
  FontWeight _fontWeight;

  TypeFace({String fontFamily, FontWeight fontWeight = FontWeight.w400}) {
    _fontFamily = fontFamily;
    _fontWeight = fontWeight;
  }

  // ignore: unnecessary_getters_setters
  FontWeight get fontWeight => _fontWeight;

  // ignore: unnecessary_getters_setters
  set fontWeight(FontWeight value) {
    _fontWeight = value;
  }

  // ignore: unnecessary_getters_setters
  String get fontFamily => _fontFamily;

  // ignore: unnecessary_getters_setters
  set fontFamily(String value) {
    _fontFamily = value;
  }
}
