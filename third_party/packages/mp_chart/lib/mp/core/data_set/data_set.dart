import 'package:mp_chart/mp/core/data_set/base_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/rounding.dart';

abstract class DataSet<T extends Entry> extends BaseDataSet<T> {
  /// the entries that this DataSet represents / holds together
  List<T> _values;

  /// maximum y-value in the value array
  double _yMax = -double.infinity;

  /// minimum y-value in the value array
  double _yMin = double.infinity;

  /// maximum x-value in the value array
  double _xMax = -double.infinity;

  /// minimum x-value in the value array
  double _xMin = double.infinity;

  /// Creates a  DataSet object with the given values (entries) it represents. Also, a
  /// label that describes the DataSet can be specified. The label can also be
  /// used to retrieve the DataSet from a ChartData object.
  ///
  /// @param values
  /// @param label
  DataSet(List<T> values, String label) : super.withLabel(label) {
    this._values = values;

    if (_values == null) _values = List<T>();

    calcMinMax();
  }

  @override
  void calcMinMax() {
    if (_values == null || _values.isEmpty) return;

    _yMax = -double.infinity;
    _yMin = double.infinity;
    _xMax = -double.infinity;
    _xMin = double.infinity;

    for (T e in _values) {
      calcMinMax1(e);
    }
  }

  @override
  void calcMinMaxY(double fromX, double toX) {
    if (_values == null || _values.isEmpty) return;

    _yMax = -double.infinity;
    _yMin = double.infinity;

    int indexFrom = getEntryIndex1(fromX, double.nan, Rounding.DOWN);
    int indexTo = getEntryIndex1(toX, double.nan, Rounding.UP);

    for (int i = indexFrom; i <= indexTo; i++) {
      // only recalculate y
      calcMinMaxY1(_values[i]);
    }
  }

  /// Updates the min and max x and y value of this DataSet based on the given Entry.
  ///
  /// @param e
  void calcMinMax1(T e) {
    if (e == null) return;

    calcMinMaxX1(e);

    calcMinMaxY1(e);
  }

  void calcMinMaxX1(T e) {
    if (e.x < _xMin) _xMin = e.x;

    if (e.x > _xMax) _xMax = e.x;
  }

  void calcMinMaxY1(T e) {
    if (e.y < _yMin) _yMin = e.y;

    if (e.y > _yMax) _yMax = e.y;
  }

  @override
  int getEntryCount() {
    return _values.length;
  }

  List<T> get values => _values;

  /// Sets the array of entries that this DataSet represents, and calls notifyDataSetChanged()
  ///
  /// @return
  void setValues(List<T> values) {
    _values = values;
    notifyDataSetChanged();
  }

  /// Provides an exact copy of the DataSet this method is used on.
  ///
  /// @return
  DataSet<T> copy1();

  ///
  /// @param dataSet
  void copy2(DataSet dataSet) {
    super.copy(dataSet);
  }

  @override
  String toString() {
    return 'DataSet{_values.length: ${_values.length},\n _yMax: $_yMax,\n _yMin: $_yMin,\n _xMax: $_xMax,\n _xMin: $_xMin}';
  }

  /// Returns a simple string representation of the DataSet with the type and
  /// the number of Entries.
  ///
  /// @return
  String toSimpleString() {
    StringBuffer buffer = StringBuffer();
    buffer.write("DataSet, label: " +
        (getLabel() == null ? "" : getLabel()) +
        ", entries:${_values.length}\n");
    return buffer.toString();
  }

  set yMax(double value) {
    _yMax = value;
  }

  set yMin(double value) {
    _yMin = value;
  }

  set xMax(double value) {
    _xMax = value;
  }

  set xMin(double value) {
    _xMin = value;
  }

  @override
  double getYMin() {
    return _yMin;
  }

  @override
  double getYMax() {
    return _yMax;
  }

  @override
  double getXMin() {
    return _xMin;
  }

  @override
  double getXMax() {
    return _xMax;
  }

  @override
  void addEntryOrdered(T e) {
    if (e == null) return;

    if (_values == null) {
      _values = List<T>();
    }

    calcMinMax1(e);

    if (_values.length > 0 && _values[_values.length - 1].x > e.x) {
      int closestIndex = getEntryIndex1(e.x, e.y, Rounding.UP);
      _values.insert(closestIndex, e);
    } else {
      _values.add(e);
    }
  }

  @override
  void clear() {
    _values.clear();
    notifyDataSetChanged();
  }

  @override
  bool addEntry(T e) {
    if (e == null) return false;

    List<T> valueDatas = values;
    if (valueDatas == null) {
      valueDatas = List<T>();
    }

    calcMinMax1(e);

    // add the entry
    valueDatas.add(e);
    return true;
  }

  @override
  bool removeEntry1(T e) {
    if (e == null) return false;

    if (_values == null) return false;

    // remove the entry
    bool removed = _values.remove(e);

    if (removed) {
      calcMinMax();
    }

    return removed;
  }

  @override
  int getEntryIndex2(Entry e) {
    return _values.indexOf(e);
  }

  @override
  T getEntryForXValue1(double xValue, double closestToY, Rounding rounding) {
    int index = getEntryIndex1(xValue, closestToY, rounding);
    if (index > -1) return _values[index];
    return null;
  }

  @override
  T getEntryForXValue2(double xValue, double closestToY) {
    return getEntryForXValue1(xValue, closestToY, Rounding.CLOSEST);
  }

  @override
  T getEntryForIndex(int index) {
    return _values[index];
  }

  @override
  int getEntryIndex1(double xValue, double closestToY, Rounding rounding) {
    if (_values == null || _values.isEmpty) return -1;

    int low = 0;
    int high = _values.length - 1;
    int closest = high;

    while (low < high) {
      int m = (low + high) ~/ 2;

      final double d1 = _values[m].x - xValue,
          d2 = _values[m + 1].x - xValue,
          ad1 = d1.abs(),
          ad2 = d2.abs();

      if (ad2 < ad1) {
        // [m + 1] is closer to xValue
        // Search in an higher place
        low = m + 1;
      } else if (ad1 < ad2) {
        // [m] is closer to xValue
        // Search in a lower place
        high = m;
      } else {
        // We have multiple sequential x-value with same distance

        if (d1 >= 0.0) {
          // Search in a lower place
          high = m;
        } else if (d1 < 0.0) {
          // Search in an higher place
          low = m + 1;
        }
      }

      closest = high;
    }

    if (closest != -1) {
      double closestXValue = _values[closest].x;
      if (rounding == Rounding.UP) {
        // If rounding up, and found x-value is lower than specified x, and we can go upper...
        if (closestXValue < xValue && closest < _values.length - 1) {
          ++closest;
        }
      } else if (rounding == Rounding.DOWN) {
        // If rounding down, and found x-value is upper than specified x, and we can go lower...
        if (closestXValue > xValue && closest > 0) {
          --closest;
        }
      }

      // Search by closest to y-value
      if (!(closestToY.isNaN)) {
        while (closest > 0 && _values[closest - 1].x == closestXValue)
          closest -= 1;

        double closestYValue = _values[closest].y;
        int closestYIndex = closest;

        while (true) {
          closest += 1;
          if (closest >= _values.length) break;

          final Entry value = _values[closest];

          if (value.x != closestXValue) break;

          if ((value.y - closestToY).abs() <
              (closestYValue - closestToY).abs()) {
            closestYValue = closestToY;
            closestYIndex = closest;
          }
        }

        closest = closestYIndex;
      }
    }

    return closest;
  }

  @override
  List<T> getEntriesForXValue(double xValue) {
    List<T> entries = List<T>();

    int low = 0;
    int high = _values.length - 1;

    while (low <= high) {
      int m = (high + low) ~/ 2;
      T entry = _values[m];

      // if we have a match
      if (xValue == entry.x) {
        while (m > 0 && _values[m - 1].x == xValue) m--;

        high = _values.length;

        // loop over all "equal" entries
        for (; m < high; m++) {
          entry = _values[m];
          if (entry.x == xValue) {
            entries.add(entry);
          } else {
            break;
          }
        }

        break;
      } else {
        if (xValue > entry.x)
          low = m + 1;
        else
          high = m - 1;
      }
    }

    return entries;
  }
}
