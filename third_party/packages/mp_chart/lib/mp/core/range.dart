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

  double get from => _from;

  set from(double value) {
    _from = value;
  }

  double get to => _to;

  set to(double value) {
    _to = value;
  }
}
