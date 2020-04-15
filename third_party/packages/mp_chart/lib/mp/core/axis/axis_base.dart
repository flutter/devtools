import 'dart:ui';

import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/component.dart';
import 'package:mp_chart/mp/core/limit_line.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/default_axis_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

abstract class AxisBase extends ComponentBase {
  /// custom formatter that is used instead of the auto-formatter if set
  ValueFormatter _axisValueFormatter;

  Color _gridColor = ColorUtils.GRAY;

  double _gridLineWidth = 1;

  Color _axisLineColor = ColorUtils.GRAY;

  double _axisLineWidth = 1;

  List<double> _entries = List();

  List<double> _centeredEntries = List();

  /// the number of entries the legend contains
  int _entryCount = 0;

  /// the number of decimal digits to use
  int _decimals = 0;

  /// the number of label entries the axis should have, default 6
  int _labelCount = 6;

  /// the minimum interval between axis values
  double _granularity = 1.0;

  /// When true, axis labels are controlled by the `granularity` property.
  /// When false, axis values could possibly be repeated.
  /// This could happen if two adjacent axis values are rounded to same value.
  /// If using granularity this could be avoided by having fewer axis values visible.
  bool _granularityEnabled = false;

  /// if true, the set number of y-labels will be forced
  bool _forceLabels = false;

  /// flag indicating if the grid lines for this axis should be drawn
  bool _drawGridLines = true;

  /// flag that indicates if the line alongside the axis is drawn or not
  bool _drawAxisLine = true;

  /// flag that indicates of the labels of this axis should be drawn or not
  bool _drawLabels = true;

  bool _centerAxisLabels = false;

  /// the path effect of the axis line that makes dashed lines possible
  DashPathEffect _axisLineDashPathEffect;

  /// the path effect of the grid lines that makes dashed lines possible
  DashPathEffect _gridDashPathEffect;

  /// array of limit lines that can be set for the axis
  List<LimitLine> _limitLines;

  /// flag indicating the limit lines layer depth
  bool _drawLimitLineBehindData = false;

  /// flag indicating the grid lines layer depth
  bool _drawGridLinesBehindData = true;

  /// Extra spacing for `axisMinimum` to be added to automatically calculated `axisMinimum`
  double _spaceMin = 0;

  /// Extra spacing for `axisMaximum` to be added to automatically calculated `axisMaximum`
  double _spaceMax = 0;

  /// flag indicating that the axis-min value has been customized
  bool _customAxisMin = false;

  /// flag indicating that the axis-max value has been customized
  bool _customAxisMax = false;

  /// don't touch this direclty, use setter
  double _axisMaximum = 0;

  /// don't touch this directly, use setter
  double _axisMinimum = 0;

  /// the total range of values this axis covers
  double _axisRange = 0;

  AxisBase() {
    textSize = 10;
    xOffset = 5;
    yOffset = 5;
    this._limitLines = List<LimitLine>();
  }

  // ignore: unnecessary_getters_setters
  ValueFormatter get axisValueFormatter => _axisValueFormatter;

  // ignore: unnecessary_getters_setters
  set axisValueFormatter(ValueFormatter value) {
    _axisValueFormatter = value;
  }

  // ignore: unnecessary_getters_setters
  double get axisRange => _axisRange;

  // ignore: unnecessary_getters_setters
  set axisRange(double value) {
    _axisRange = value;
  }

  // ignore: unnecessary_getters_setters
  set axisMaximum(double value) {
    _axisMaximum = value;
  }

  // ignore: unnecessary_getters_setters
  set axisMinimum(double value) {
    _axisMinimum = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawGridLines => _drawGridLines;

  // ignore: unnecessary_getters_setters
  set drawGridLines(bool value) {
    _drawGridLines = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawAxisLine => _drawAxisLine;

  // ignore: unnecessary_getters_setters
  set drawAxisLine(bool value) {
    _drawAxisLine = value;
  }

  set centerAxisLabels(bool value) {
    _centerAxisLabels = value;
  }

  bool isCenterAxisLabelsEnabled() {
    return _centerAxisLabels && _entryCount > 0;
  }

  // ignore: unnecessary_getters_setters
  Color get gridColor => _gridColor;

  // ignore: unnecessary_getters_setters
  set gridColor(Color value) {
    _gridColor = value;
  }

  // ignore: unnecessary_getters_setters
  double get axisLineWidth => _axisLineWidth;

  // ignore: unnecessary_getters_setters
  set axisLineWidth(double value) {
    _axisLineWidth = value;
  }

  // ignore: unnecessary_getters_setters
  double get gridLineWidth => _gridLineWidth;

  // ignore: unnecessary_getters_setters
  set gridLineWidth(double value) {
    _gridLineWidth = value;
  }

  // ignore: unnecessary_getters_setters
  Color get axisLineColor => _axisLineColor;

  // ignore: unnecessary_getters_setters
  set axisLineColor(Color value) {
    _axisLineColor = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawLabels => _drawLabels;

  // ignore: unnecessary_getters_setters
  set drawLabels(bool value) {
    _drawLabels = value;
  }

  /// Sets the number of label entries for the y-axis max = 25, min = 2, default: 6, be aware
  /// that this number is not fixed.
  ///
  /// @param count the number of y-axis labels that should be displayed
  void setLabelCount1(int count) {
    if (count > 25) count = 25;
    if (count < 2) count = 2;
    _labelCount = count;
    _forceLabels = false;
  }

  /// sets the number of label entries for the y-axis max = 25, min = 2, default: 6, be aware
  /// that this number is not
  /// fixed (if force == false) and can only be approximated.
  ///
  /// @param count the number of y-axis labels that should be displayed
  /// @param force if enabled, the set label count will be forced, meaning that the exact
  ///              specified count of labels will
  ///              be drawn and evenly distributed alongside the axis - this might cause labels
  ///              to have uneven values
  void setLabelCount2(int count, bool force) {
    setLabelCount1(count);
    _forceLabels = force;
  }

  bool get forceLabels => _forceLabels;

  int get labelCount => _labelCount;

  // ignore: unnecessary_getters_setters
  bool get granularityEnabled => _granularityEnabled;

  // ignore: unnecessary_getters_setters
  set granularityEnabled(bool value) {
    _granularityEnabled = value;
  }

  double get granularity => _granularity;

  /// Set a minimum interval for the axis when zooming in. The axis is not allowed to go below
  /// that limit. This can be used to avoid label duplicating when zooming in.
  ///
  /// @param granularity
  void setGranularity(double granularity) {
    _granularity = granularity;
    // set this to true if it was disabled, as it makes no sense to call this method with granularity disabled
    _granularityEnabled = true;
  }

  /// Adds a  LimitLine to this axis.
  ///
  /// @param l
  void addLimitLine(LimitLine l) {
    _limitLines.add(l);
  }

  /// Removes the specified LimitLine from the axis.
  ///
  /// @param l
  void removeLimitLine(LimitLine l) {
    _limitLines.remove(l);
  }

  /// Removes all LimitLines from the axis.
  void removeAllLimitLines() {
    _limitLines.clear();
  }

  /// Returns the LimitLines of this axis.
  ///
  /// @return
  List<LimitLine> getLimitLines() {
    return _limitLines;
  }

  // ignore: unnecessary_getters_setters
  bool get drawLimitLineBehindData => _drawLimitLineBehindData;

  // ignore: unnecessary_getters_setters
  set drawLimitLineBehindData(bool value) {
    _drawLimitLineBehindData = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawGridLinesBehindData => _drawGridLinesBehindData;

  // ignore: unnecessary_getters_setters
  set drawGridLinesBehindData(bool value) {
    _drawGridLinesBehindData = value;
  }

  /// Returns the longest formatted label (in terms of characters), this axis
  /// contains.
  ///
  /// @return
  String getLongestLabel() {
    String longest = "";

    for (int i = 0; i < _entries.length; i++) {
      String text = getFormattedLabel(i);

      if (text != null && longest.length < text.length) longest = text;
    }

    return longest;
  }

  String getFormattedLabel(int index) {
    if (index < 0 || index >= _entries.length)
      return "";
    else
      return getValueFormatter().getAxisLabel(_entries[index], this);
  }

  /// Sets the formatter to be used for formatting the axis labels. If no formatter is set, the
  /// chart will
  /// automatically determine a reasonable formatting (concerning decimals) for all the values
  /// that are drawn inside
  /// the chart. Use chart.getDefaultValueFormatter() to use the formatter calculated by the chart.
  ///
  /// @param f
  void setValueFormatter(ValueFormatter f) {
    if (f == null)
      _axisValueFormatter = DefaultAxisValueFormatter(_decimals);
    else
      _axisValueFormatter = f;
  }

  /// Returns the formatter used for formatting the axis labels.
  ///
  /// @return
  ValueFormatter getValueFormatter() {
    if (_axisValueFormatter == null ||
        (_axisValueFormatter is DefaultAxisValueFormatter &&
            (_axisValueFormatter as DefaultAxisValueFormatter).digits !=
                _decimals))
      _axisValueFormatter = DefaultAxisValueFormatter(_decimals);

    return _axisValueFormatter;
  }

  /// Enables the grid line to be drawn in dashed mode, e.g. like this
  /// "- - - - - -". THIS ONLY WORKS IF HARDWARE-ACCELERATION IS TURNED OFF.
  /// Keep in mind that hardware acceleration boosts performance.
  ///
  /// @param lineLength  the length of the line pieces
  /// @param spaceLength the length of space in between the pieces
  /// @param phase       offset, in degrees (normally, use 0)
  void enableGridDashedLine(
      double lineLength, double spaceLength, double phase) {
    _gridDashPathEffect = DashPathEffect(lineLength, spaceLength, phase);
  }

  // ignore: unnecessary_getters_setters
  DashPathEffect get gridDashPathEffect => _gridDashPathEffect;

  // ignore: unnecessary_getters_setters
  set gridDashPathEffect(DashPathEffect value) {
    _gridDashPathEffect = value;
  }

  /// Disables the grid line to be drawn in dashed mode.
  void disableGridDashedLine() {
    _gridDashPathEffect = null;
  }

  /// Returns true if the grid dashed-line effect is enabled, false if not.
  ///
  /// @return
  bool isGridDashedLineEnabled() {
    return _gridDashPathEffect == null ? false : true;
  }

  /// Enables the axis line to be drawn in dashed mode, e.g. like this
  /// "- - - - - -". THIS ONLY WORKS IF HARDWARE-ACCELERATION IS TURNED OFF.
  /// Keep in mind that hardware acceleration boosts performance.
  ///
  /// @param lineLength  the length of the line pieces
  /// @param spaceLength the length of space in between the pieces
  /// @param phase       offset, in degrees (normally, use 0)
  void enableAxisLineDashedLine(
      double lineLength, double spaceLength, double phase) {
    _axisLineDashPathEffect = DashPathEffect(lineLength, spaceLength, phase);
  }

  /// Disables the axis line to be drawn in dashed mode.
  void disableAxisLineDashedLine() {
    _axisLineDashPathEffect = null;
  }

  /// Returns true if the axis dashed-line effect is enabled, false if not.
  ///
  /// @return
  bool isAxisLineDashedLineEnabled() {
    return _axisLineDashPathEffect == null ? false : true;
  }

  // ignore: unnecessary_getters_setters
  DashPathEffect get axisLineDashPathEffect => _axisLineDashPathEffect;

  // ignore: unnecessary_getters_setters
  set axisLineDashPathEffect(DashPathEffect value) {
    _axisLineDashPathEffect = value;
  }

  /// ###### BELOW CODE RELATED TO CUSTOM AXIS VALUES ######

  // ignore: unnecessary_getters_setters
  double get axisMaximum => _axisMaximum;

  // ignore: unnecessary_getters_setters
  double get axisMinimum => _axisMinimum;

  /// By calling this method, any custom maximum value that has been previously set is reseted,
  /// and the calculation is
  /// done automatically.
  void resetAxisMaximum() {
    _customAxisMax = false;
  }

  bool get customAxisMax => _customAxisMax;

  /// By calling this method, any custom minimum value that has been previously set is reseted,
  /// and the calculation is
  /// done automatically.
  void resetAxisMinimum() {
    _customAxisMin = false;
  }

  bool get customAxisMin => _customAxisMin;

  /// Returns true if the axis min value has been customized (and is not calculated automatically)
  ///
  /// @return
  bool isAxisMinCustom() {
    return _customAxisMin;
  }

  /// Set a custom minimum value for this axis. If set, this value will not be calculated
  /// automatically depending on
  /// the provided data. Use resetAxisMinValue() to undo this. Do not forget to call
  /// setStartAtZero(false) if you use
  /// this method. Otherwise, the axis-minimum value will still be forced to 0.
  ///
  /// @param min
  void setAxisMinimum(double min) {
    _customAxisMin = true;
    _axisMinimum = min;
    this._axisRange = (_axisMaximum - min).abs();
  }

  /// Use setAxisMinimum(...) instead.
  ///
  /// @param min
  void setAxisMinValue(double min) {
    setAxisMinimum(min);
  }

  /// Set a custom maximum value for this axis. If set, this value will not be calculated
  /// automatically depending on
  /// the provided data. Use resetAxisMaxValue() to undo this.
  ///
  /// @param max
  void setAxisMaximum(double max) {
    _customAxisMax = true;
    _axisMaximum = max;
    this._axisRange = (max - _axisMinimum).abs();
  }

  /// Use setAxisMaximum(...) instead.
  ///
  /// @param max
  void setAxisMaxValue(double max) {
    setAxisMaximum(max);
  }

  /// Calculates the minimum / maximum  and range values of the axis with the given
  /// minimum and maximum values from the chart data.
  ///
  /// @param dataMin the min value according to chart data
  /// @param dataMax the max value according to chart data
  void calculate(double dataMin, double dataMax) {
    // if custom, use value as is, else use data value
    double min = _customAxisMin ? _axisMinimum : (dataMin - _spaceMin);
    double max = _customAxisMax ? _axisMaximum : (dataMax + _spaceMax);

    // temporary range (before calculations)
    double range = (max - min).abs();

    // in case all values are equal
    if (range == 0) {
      max = max + 1;
      min = min - 1;
    }

    this._axisMinimum = min;
    this._axisMaximum = max;

    // actual range
    this._axisRange = (max - min).abs();
  }

  // ignore: unnecessary_getters_setters
  double get spaceMin => _spaceMin;

  // ignore: unnecessary_getters_setters
  set spaceMin(double value) {
    _spaceMin = value;
  }

  // ignore: unnecessary_getters_setters
  double get spaceMax => _spaceMax;

  // ignore: unnecessary_getters_setters
  set spaceMax(double value) {
    _spaceMax = value;
  }

  // ignore: unnecessary_getters_setters
  List<double> get entries => _entries;

  // ignore: unnecessary_getters_setters
  set entries(List<double> value) {
    _entries = value;
  }

  // ignore: unnecessary_getters_setters
  List<double> get centeredEntries => _centeredEntries;

  // ignore: unnecessary_getters_setters
  set centeredEntries(List<double> value) {
    _centeredEntries = value;
  }

  // ignore: unnecessary_getters_setters
  int get entryCount => _entryCount;

  // ignore: unnecessary_getters_setters
  set entryCount(int value) {
    _entryCount = value;
  }

  // ignore: unnecessary_getters_setters
  int get decimals => _decimals;

  // ignore: unnecessary_getters_setters
  set decimals(int value) {
    _decimals = value;
  }

  // ignore: unnecessary_getters_setters
  List<LimitLine> get limitLines => _limitLines;

  // ignore: unnecessary_getters_setters
  set limitLines(List<LimitLine> value) {
    _limitLines = value;
  }
}
