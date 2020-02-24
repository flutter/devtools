class Range {
  double _from;
  double _to;

  Range(this._from, this._to);

  /// Returns true if this range contains (if the value is in between) the given value, false if not.
  ///
  /// @param value
  /// @return
  bool contains(double value) {
    if (value > _from && value <= _to)
      return true;
    else
      return false;
  }

  bool isLarger(double value) {
    return value > _to;
  }

  bool isSmaller(double value) {
    return value < _from;
  }

  // ignore: unnecessary_getters_setters
  double get from => _from;

  // ignore: unnecessary_getters_setters
  set from(double value) {
    _from = value;
  }

  // ignore: unnecessary_getters_setters
  double get to => _to;

  // ignore: unnecessary_getters_setters
  set to(double value) {
    _to = value;
  }
}
