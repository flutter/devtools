import 'package:mp_chart/mp/core/poolable/point.dart';

class FSize extends Poolable {
  double _width;
  double _height;

  static ObjectPool<Poolable> pool = ObjectPool.create(256, FSize(0, 0))
    ..setReplenishPercentage(0.5);

  @override
  Poolable instantiate() {
    return FSize(0, 0);
  }

  // ignore: unnecessary_getters_setters
  double get width => _width;

  // ignore: unnecessary_getters_setters
  set width(double value) {
    _width = value;
  }

  // ignore: unnecessary_getters_setters
  double get height => _height;

  // ignore: unnecessary_getters_setters
  set height(double value) {
    _height = value;
  }

  static FSize getInstance(final double width, final double height) {
    FSize result = pool.get();
    result._width = width;
    result._height = height;
    return result;
  }

  static void recycleInstance(FSize instance) {
    pool.recycle1(instance);
  }

  static void recycleInstances(List<FSize> instances) {
    pool.recycle2(instances);
  }

  FSize(this._width, this._height);

  bool equals(final Object obj) {
    if (obj == null) {
      return false;
    }
    if (this == obj) {
      return true;
    }
    if (obj is FSize) {
      final FSize other = obj;
      return _width == other._width && _height == other._height;
    }
    return false;
  }

  @override
  String toString() {
    return "${_width}x$_height";
  }

  @override
  // ignore: hash_and_equals
  int get hashCode {
    return _width.toInt() ^ _height.toInt();
  }
}
