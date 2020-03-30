import 'dart:ui' as ui;

import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/utils/dart_adapter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

class ChartData<T extends IDataSet<Entry>> {
  /// maximum y-value in the value array across all axes
  double _yMax = -double.infinity;

  /// the minimum y-value in the value array across all axes
  double _yMin = double.infinity;

  /// maximum x-value in the value array
  double _xMax = -double.infinity;

  /// minimum x-value in the value array
  double _xMin = double.infinity;

  double _leftAxisMax = -double.infinity;

  double _leftAxisMin = double.infinity;

  double _rightAxisMax = -double.infinity;

  double _rightAxisMin = double.infinity;

  /// array that holds all DataSets the ChartData object represents
  List<T> _dataSets;

  /// Default constructor.
  ChartData() {
    _dataSets = List<T>();
  }

  /// Constructor taking single or multiple DataSet objects.
  ///
  /// @param dataSets
  ChartData.fromList(List<T> dataSets) {
    _dataSets = dataSets;
    notifyDataChanged();
  }

  /// Call this method to let the ChartData know that the underlying data has
  /// changed. Calling this performs all necessary recalculations needed when
  /// the contained data has changed.
  void notifyDataChanged() {
    calcMinMax1();
  }

  /// Calc minimum and maximum y-values over all DataSets.
  /// Tell DataSets to recalculate their min and max y-values, this is only needed for autoScaleMinMax.
  ///
  /// @param fromX the x-value to start the calculation from
  /// @param toX   the x-value to which the calculation should be performed
  void calcMinMaxY(double fromX, double toX) {
    for (T set in _dataSets) {
      set.calcMinMaxY(fromX, toX);
    }

    // apply the  data
    calcMinMax1();
  }

  /// Calc minimum and maximum values (both x and y) over all DataSets.
  void calcMinMax1() {
    if (_dataSets == null) return;

    _yMax = -double.infinity;
    _yMin = double.infinity;
    _xMax = -double.infinity;
    _xMin = double.infinity;

    for (T set in _dataSets) {
      calcMinMax3(set);
    }

    _leftAxisMax = -double.infinity;
    _leftAxisMin = double.infinity;
    _rightAxisMax = -double.infinity;
    _rightAxisMin = double.infinity;

    // left axis
    T firstLeft = getFirstLeft(_dataSets);

    if (firstLeft != null) {
      _leftAxisMax = firstLeft.getYMax();
      _leftAxisMin = firstLeft.getYMin();

      for (T dataSet in _dataSets) {
        if (dataSet.getAxisDependency() == AxisDependency.LEFT) {
          if (dataSet.getYMin() < _leftAxisMin)
            _leftAxisMin = dataSet.getYMin();

          if (dataSet.getYMax() > _leftAxisMax)
            _leftAxisMax = dataSet.getYMax();
        }
      }
    }

    // right axis
    T firstRight = getFirstRight(_dataSets);

    if (firstRight != null) {
      _rightAxisMax = firstRight.getYMax();
      _rightAxisMin = firstRight.getYMin();

      for (T dataSet in _dataSets) {
        if (dataSet.getAxisDependency() == AxisDependency.RIGHT) {
          if (dataSet.getYMin() < _rightAxisMin)
            _rightAxisMin = dataSet.getYMin();

          if (dataSet.getYMax() > _rightAxisMax)
            _rightAxisMax = dataSet.getYMax();
        }
      }
    }
  }

  /** ONLY GETTERS AND SETTERS BELOW THIS */

  /// returns the number of LineDataSets this object contains
  ///
  /// @return
  int getDataSetCount() {
    if (_dataSets == null) return 0;
    return _dataSets.length;
  }

  /// Returns the smallest y-value the data object contains.
  ///
  /// @return
  double getYMin1() {
    return _yMin;
  }

  /// Returns the minimum y-value for the specified axis.
  ///
  /// @param axis
  /// @return
  double getYMin2(AxisDependency axis) {
    if (axis == AxisDependency.LEFT) {
      if (_leftAxisMin.isInfinite) {
        return _rightAxisMin;
      } else
        return _leftAxisMin;
    } else {
      if (_rightAxisMin.isInfinite) {
        return _leftAxisMin;
      } else
        return _rightAxisMin;
    }
  }

  /// Returns the greatest y-value the data object contains.
  ///
  /// @return
  double getYMax1() {
    return _yMax;
  }

  /// Returns the maximum y-value for the specified axis.
  ///
  /// @param axis
  /// @return
  double getYMax2(AxisDependency axis) {
    if (axis == AxisDependency.LEFT) {
      if (_leftAxisMax == -double.infinity) {
        return _rightAxisMax;
      } else
        return _leftAxisMax;
    } else {
      if (_rightAxisMax == -double.infinity) {
        return _leftAxisMax;
      } else
        return _rightAxisMax;
    }
  }

  // ignore: unnecessary_getters_setters
  double get xMax => _xMax;

  // ignore: unnecessary_getters_setters
  double get xMin => _xMin;

  // ignore: unnecessary_getters_setters
  set xMax(double value) {
    _xMax = value;
  }

  // ignore: unnecessary_getters_setters
  List<T> get dataSets => _dataSets;

  // ignore: unnecessary_getters_setters
  set dataSets(List<T> value) {
    _dataSets = value;
  }

  // ignore: unnecessary_getters_setters
  double get yMax => _yMax;

  // ignore: unnecessary_getters_setters
  set yMax(double value) {
    _yMax = value;
  }

  /// Retrieve the index of a DataSet with a specific label from the ChartData.
  /// Search can be case sensitive or not. IMPORTANT: This method does
  /// calculations at runtime, do not over-use in performance critical
  /// situations.
  ///
  /// @param dataSets   the DataSet array to search
  /// @param label
  /// @param ignorecase if true, the search is not case-sensitive
  /// @return
  int getDataSetIndexByLabel(List<T> dataSets, String label, bool ignorecase) {
    if (ignorecase) {
      for (int i = 0; i < dataSets.length; i++)
        if (DartAdapterUtils.equalsIgnoreCase(label, dataSets[i].getLabel()))
          return i;
    } else {
      for (int i = 0; i < dataSets.length; i++)
        if (label == dataSets[i].getLabel()) return i;
    }

    return -1;
  }

  /// Returns the labels of all DataSets as a string array.
  ///
  /// @return
  List<String> getDataSetLabels() {
    List<String> types = List(_dataSets.length);

    for (int i = 0; i < _dataSets.length; i++) {
      types[i] = _dataSets[i].getLabel();
    }

    return types;
  }

  /// Get the Entry for a corresponding highlight object
  ///
  /// @param highlight
  /// @return the entry that is highlighted
  Entry getEntryForHighlight(Highlight highlight) {
    if (highlight.dataSetIndex >= _dataSets.length)
      return null;
    else {
      return _dataSets[highlight.dataSetIndex]
          .getEntryForXValue2(highlight.x, highlight.y);
    }
  }

  /// Returns the DataSet object with the given label. Search can be case
  /// sensitive or not. IMPORTANT: This method does calculations at runtime.
  /// Use with care in performance critical situations.
  ///
  /// @param label
  /// @param ignorecase
  /// @return
  T getDataSetByLabel(String label, bool ignorecase) {
    int index = getDataSetIndexByLabel(_dataSets, label, ignorecase);

    if (index < 0 || index >= _dataSets.length)
      return null;
    else
      return _dataSets[index];
  }

  T getDataSetByIndex(int index) {
    if (_dataSets == null || index < 0 || index >= _dataSets.length)
      return null;

    return _dataSets[index];
  }

  /// Adds a DataSet dynamically.
  ///
  /// @param d
  void addDataSet(T d) {
    if (d == null) return;

    calcMinMax3(d);

    _dataSets.add(d);
  }

  /// Removes the given DataSet from this data object. Also recalculates all
  /// minimum and maximum values. Returns true if a DataSet was removed, false
  /// if no DataSet could be removed.
  ///
  /// @param d
  bool removeDataSet1(T d) {
    if (d == null) return false;

    bool removed = _dataSets.remove(d);

    // if a DataSet was removed
    if (removed) {
      calcMinMax1();
    }

    return removed;
  }

  /// Removes the DataSet at the given index in the DataSet array from the data
  /// object. Also recalculates all minimum and maximum values. Returns true if
  /// a DataSet was removed, false if no DataSet could be removed.
  ///
  /// @param index
  bool removeDataSet2(int index) {
    if (index >= _dataSets.length || index < 0) return false;

    T set = _dataSets[index];
    return removeDataSet1(set);
  }

  /// Adds an Entry to the DataSet at the specified index.
  /// Entries are added to the end of the list.
  ///
  /// @param e
  /// @param dataSetIndex
  void addEntry(Entry e, int dataSetIndex) {
    if (_dataSets.length > dataSetIndex && dataSetIndex >= 0) {
      IDataSet set = _dataSets[dataSetIndex];
      // add the entry to the dataset
      if (!set.addEntry(e)) return;

      calcMinMax2(e, set.getAxisDependency());
    }
  }

  /// Adjusts the current minimum and maximum values based on the provided Entry object.
  ///
  /// @param e
  /// @param axis
  void calcMinMax2(Entry e, AxisDependency axis) {
    if (_yMax < e.y) _yMax = e.y;
    if (_yMin > e.y) _yMin = e.y;

    if (_xMax < e.x) _xMax = e.x;
    if (_xMin > e.x) _xMin = e.x;

    if (axis == AxisDependency.LEFT) {
      if (_leftAxisMax < e.y) _leftAxisMax = e.y;
      if (_leftAxisMin > e.y) _leftAxisMin = e.y;
    } else {
      if (_rightAxisMax < e.y) _rightAxisMax = e.y;
      if (_rightAxisMin > e.y) _rightAxisMin = e.y;
    }
  }

  /// Adjusts the minimum and maximum values based on the given DataSet.
  ///
  /// @param d
  void calcMinMax3(T d) {
    if (_yMax < d.getYMax()) _yMax = d.getYMax();
    if (_yMin > d.getYMin()) _yMin = d.getYMin();

    if (_xMax < d.getXMax()) _xMax = d.getXMax();
    if (_xMin > d.getXMin()) _xMin = d.getXMin();

    if (d.getAxisDependency() == AxisDependency.LEFT) {
      if (_leftAxisMax < d.getYMax()) _leftAxisMax = d.getYMax();
      if (_leftAxisMin > d.getYMin()) _leftAxisMin = d.getYMin();
    } else {
      if (_rightAxisMax < d.getYMax()) _rightAxisMax = d.getYMax();
      if (_rightAxisMin > d.getYMin()) _rightAxisMin = d.getYMin();
    }
  }

  /// Removes the given Entry object from the DataSet at the specified index.
  ///
  /// @param e
  /// @param dataSetIndex
  bool removeEntry1(Entry e, int dataSetIndex) {
    // entry null, outofbounds
    if (e == null || dataSetIndex >= _dataSets.length) return false;

    IDataSet set = _dataSets[dataSetIndex];

    if (set != null) {
      // remove the entry from the dataset
      bool removed = set.removeEntry1(e);

      if (removed) {
        calcMinMax1();
      }

      return removed;
    } else
      return false;
  }

  /// Removes the Entry object closest to the given DataSet at the
  /// specified index. Returns true if an Entry was removed, false if no Entry
  /// was found that meets the specified requirements.
  ///
  /// @param xValue
  /// @param dataSetIndex
  /// @return
  bool removeEntry2(double xValue, int dataSetIndex) {
    if (dataSetIndex >= _dataSets.length) return false;

    IDataSet dataSet = _dataSets[dataSetIndex];
    Entry e = dataSet.getEntryForXValue2(xValue, double.nan);

    if (e == null) return false;

    return removeEntry1(e, dataSetIndex);
  }

  /// Returns the DataSet that contains the provided Entry, or null, if no
  /// DataSet contains this Entry.
  ///
  /// @param e
  /// @return
  T getDataSetForEntry(Entry e) {
    if (e == null) return null;

    for (int i = 0; i < _dataSets.length; i++) {
      T set = _dataSets[i];

      for (int j = 0; j < set.getEntryCount(); j++) {
        if (e == set.getEntryForXValue2(e.x, e.y)) return set;
      }
    }

    return null;
  }

  /// Returns all colors used across all DataSet objects this object
  /// represents.
  ///
  /// @return
  List<ui.Color> getColors() {
    if (_dataSets == null) return null;

    int clrcnt = 0;

    for (int i = 0; i < _dataSets.length; i++) {
      clrcnt += _dataSets[i].getColors().length;
    }

    List<ui.Color> colors = List(clrcnt);
    int cnt = 0;

    for (int i = 0; i < _dataSets.length; i++) {
      List<ui.Color> clrs = _dataSets[i].getColors();

      for (ui.Color clr in clrs) {
        colors[cnt] = clr;
        cnt++;
      }
    }

    return colors;
  }

  /// Returns the index of the provided DataSet in the DataSet array of this data object, or -1 if it does not exist.
  ///
  /// @param dataSet
  /// @return
  int getIndexOfDataSet(T dataSet) {
    return _dataSets.indexOf(dataSet);
  }

  /// Returns the first DataSet from the datasets-array that has it's dependency on the left axis.
  /// Returns null if no DataSet with left dependency could be found.
  ///
  /// @return
  T getFirstLeft(List<T> sets) {
    for (T dataSet in sets) {
      if (dataSet.getAxisDependency() == AxisDependency.LEFT) return dataSet;
    }
    return null;
  }

  /// Returns the first DataSet from the datasets-array that has it's dependency on the right axis.
  /// Returns null if no DataSet with right dependency could be found.
  ///
  /// @return
  T getFirstRight(List<T> sets) {
    for (T dataSet in sets) {
      if (dataSet.getAxisDependency() == AxisDependency.RIGHT) return dataSet;
    }
    return null;
  }

  /// Sets a custom IValueFormatter for all DataSets this data object contains.
  ///
  /// @param f
  void setValueFormatter(ValueFormatter f) {
    if (f == null)
      return;
    else {
      for (IDataSet set in _dataSets) {
        set.setValueFormatter(f);
      }
    }
  }

  /// Sets the color of the value-text (color in which the value-labels are
  /// drawn) for all DataSets this data object contains.
  ///
  /// @param color
  void setValueTextColor(ui.Color color) {
    for (IDataSet set in _dataSets) {
      set.setValueTextColor(color);
    }
  }

  /// Sets the same list of value-colors for all DataSets this
  /// data object contains.
  ///
  /// @param colors
  void setValueTextColors(List<ui.Color> colors) {
    for (IDataSet set in _dataSets) {
      set.setValueTextColors(colors);
    }
  }

  /// Sets the Typeface for all value-labels for all DataSets this data object
  /// contains.
  ///
  /// @param tf
  void setValueTypeface(TypeFace tf) {
    for (IDataSet set in _dataSets) {
      set.setValueTypeface(tf);
    }
  }

  /// Sets the size (in dp) of the value-text for all DataSets this data object
  /// contains.
  ///
  /// @param size
  void setValueTextSize(double size) {
    for (IDataSet set in _dataSets) {
      set.setValueTextSize(size);
    }
  }

  /// Enables / disables drawing values (value-text) for all DataSets this data
  /// object contains.
  ///
  /// @param enabled
  void setDrawValues(bool enabled) {
    for (IDataSet set in _dataSets) {
      set.setDrawValues(enabled);
    }
  }

  /// Enables / disables highlighting values for all DataSets this data object
  /// contains. If set to true, this means that values can
  /// be highlighted programmatically or by touch gesture.
  void setHighlightEnabled(bool enabled) {
    for (IDataSet set in _dataSets) {
      set.setHighlightEnabled(enabled);
    }
  }

  /// Returns true if highlighting of all underlying values is enabled, false
  /// if not.
  ///
  /// @return
  bool isHighlightEnabled() {
    for (IDataSet set in _dataSets) {
      if (!set.isHighlightEnabled()) return false;
    }
    return true;
  }

  /// Clears this data object from all DataSets and removes all Entries. Don't
  /// forget to invalidate the chart after this.
  void clearValues() {
    if (_dataSets != null) {
      _dataSets.clear();
    }
    notifyDataChanged();
  }

  /// Checks if this data object contains the specified DataSet. Returns true
  /// if so, false if not.
  ///
  /// @param dataSet
  /// @return
  bool contains(T dataSet) {
    for (T set in _dataSets) {
      if (set == dataSet) return true;
    }
    return false;
  }

  /// Returns the total entry count across all DataSet objects this data object contains.
  ///
  /// @return
  int getEntryCount() {
    int count = 0;
    for (T set in _dataSets) {
      count += set.getEntryCount();
    }
    return count;
  }

  /// Returns the DataSet object with the maximum number of entries or null if there are no DataSets.
  ///
  /// @return
  T getMaxEntryCountSet() {
    if (_dataSets == null || _dataSets.isEmpty) return null;
    T max = _dataSets[0];
    for (T set in _dataSets) {
      if (set.getEntryCount() > max.getEntryCount()) max = set;
    }
    return max;
  }

  // ignore: unnecessary_getters_setters
  double get yMin => _yMin;

  // ignore: unnecessary_getters_setters
  set yMin(double value) {
    _yMin = value;
  }

  // ignore: unnecessary_getters_setters
  double get leftAxisMax => _leftAxisMax;

  // ignore: unnecessary_getters_setters
  set leftAxisMax(double value) {
    _leftAxisMax = value;
  }

  // ignore: unnecessary_getters_setters
  double get leftAxisMin => _leftAxisMin;

  // ignore: unnecessary_getters_setters
  set leftAxisMin(double value) {
    _leftAxisMin = value;
  }

  // ignore: unnecessary_getters_setters
  double get rightAxisMax => _rightAxisMax;

  // ignore: unnecessary_getters_setters
  set rightAxisMax(double value) {
    _rightAxisMax = value;
  }

  // ignore: unnecessary_getters_setters
  double get rightAxisMin => _rightAxisMin;

  // ignore: unnecessary_getters_setters
  set rightAxisMin(double value) {
    _rightAxisMin = value;
  }

  // ignore: unnecessary_getters_setters
  set xMin(double value) {
    _xMin = value;
  }
}
