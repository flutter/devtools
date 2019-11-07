import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/chart_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/chart_interface.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/highlight/i_highlighter.dart';
import 'package:mp_chart/mp/core/legend/legend.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/render/data_renderer.dart';
import 'package:mp_chart/mp/core/render/legend_renderer.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/value_formatter/default_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';

abstract class ChartPainter<T extends ChartData<IDataSet<Entry>>>
    extends CustomPainter implements ChartInterface {
  /// object that holds all data that was originally set for the chart, before
  /// it was modified or any filtering algorithms had been applied
  final T _data;

  /// object responsible for animations
  final ChartAnimator _animator;

  /// object that manages the bounds and drawing constraints of the chart
  final ViewPortHandler _viewPortHandler;

  /// The maximum distance in dp away from an entry causing it to highlight.
  final double _maxHighlightDistance;

  /// Flag that indicates if highlighting per tap (touch) is enabled
  final bool _highLightPerTapEnabled;

  final double _extraTopOffset,
      _extraRightOffset,
      _extraBottomOffset,
      _extraLeftOffset;

  /// the view that represents the marker
  final IMarker _marker;

  /// the object responsible for representing the description text
  final Description _description;

  /// if set to true, the marker view is drawn when a value is clicked
  final bool _drawMarkers;

  /// paint object used for drawing the description text in the bottom right
  /// corner of the chart
  final TextPainter _descPaint;

  /// paint object for drawing the information text when there are no values in
  /// the chart
  final TextPainter _infoPaint;

  /// the object representing the labels on the x-axis
  final XAxis _xAxis;

  /// the legend object containing all data associated with the legend
  final Legend _legend;
  final LegendRenderer _legendRenderer;

  final OnChartValueSelectedListener _selectionListener;

  final DataRendererSettingFunction _rendererSettingFunction;

  ///////////////////////////////////////////////////
  /// object responsible for rendering the data
  DataRenderer renderer;
  IHighlighter highlighter;

  /// array of Highlight objects that reference the highlighted slices in the
  /// chart
  List<Highlight> _indicesToHighlight;

  Size _size;

  /// flag that indicates if offsets calculation has already been done or not
  bool _offsetsCalculated = false;

  /// default value-formatter, number of digits depends on provided chart-data
  DefaultValueFormatter _defaultValueFormatter = DefaultValueFormatter(0);

  bool _isInit = false;

  XAxis get xAxis => _xAxis;

  Legend get legend => _legend;

  ViewPortHandler get viewPortHandler => _viewPortHandler;

  LegendRenderer get legendRenderer => _legendRenderer;

  double get extraLeftOffset => _extraLeftOffset;

  double get extraRightOffset => _extraRightOffset;

  double get extraTopOffset => _extraTopOffset;

  double get extraBottomOffset => _extraBottomOffset;

  IMarker get marker => _marker;

  bool get isDrawMarkers => _drawMarkers;

  ChartAnimator get animator => _animator;

  Size get size => _size;

  List<Highlight> get indicesToHighlight => _indicesToHighlight;

  bool get highLightPerTapEnabled => _highLightPerTapEnabled;

  ChartPainter(
      T data,
      ChartAnimator animator,
      ViewPortHandler viewPortHandler,
      double maxHighlightDistance,
      bool highLightPerTapEnabled,
      double extraLeftOffset,
      double extraTopOffset,
      double extraRightOffset,
      double extraBottomOffset,
      IMarker marker,
      Description desc,
      bool drawMarkers,
      TextPainter infoPainter,
      TextPainter descPainter,
      XAxis xAxis,
      Legend legend,
      LegendRenderer legendRenderer,
      DataRendererSettingFunction rendererSettingFunction,
      OnChartValueSelectedListener selectedListener)
      : _data = data,
        _viewPortHandler = viewPortHandler,
        _animator = animator,
        _maxHighlightDistance = maxHighlightDistance,
        _highLightPerTapEnabled = highLightPerTapEnabled,
        _extraLeftOffset = extraLeftOffset,
        _extraTopOffset = extraTopOffset,
        _extraRightOffset = extraRightOffset,
        _extraBottomOffset = extraBottomOffset,
        _marker = marker,
        _description = desc,
        _drawMarkers = drawMarkers,
        _infoPaint = infoPainter,
        _descPaint = descPainter,
        _xAxis = xAxis,
        _legend = legend,
        _legendRenderer = legendRenderer,
        _rendererSettingFunction = rendererSettingFunction,
        _selectionListener = selectedListener,
        super() {
    initDefaultNormal();
    if (data == null || data.dataSets == null || data.dataSets.length == 0) {
      return;
    }
    initDefaultWithData();
    if (_rendererSettingFunction != null && renderer != null) {
      _rendererSettingFunction(renderer);
    }
    init();
    _isInit = true;
  }

  void initDefaultWithData() {
    // calculate how many digits are needed
    _setupDefaultFormatter(_data.getYMin1(), _data.getYMax1());

    for (IDataSet set in _data.dataSets) {
      if (set.needsFormatter() ||
          set.getValueFormatter() == _defaultValueFormatter)
        set.setValueFormatter(_defaultValueFormatter);
    }
  }

  void initDefaultNormal() {}

  void init() {}

  /// Calculates the offsets of the chart to the border depending on the
  /// position of an eventual legend or depending on the length of the y-axis
  /// and x-axis labels and their position
  void calculateOffsets();

  /// Calculates the y-min and y-max value and the y-delta and x-delta value
  void calcMinMax();

  /// Calculates the required number of digits for the values that might be
  /// drawn in the chart (if enabled), and creates the default-value-formatter
  void _setupDefaultFormatter(double min1, double max1) {
    double reference = 0;

    if (_data == null || _data.getEntryCount() < 2) {
      reference = max(min1.abs(), max1.abs());
    } else {
      reference = (max1 - min1).abs();
    }

    int digits = Utils.getDecimals(reference);

    // setup the formatter with a new number of digits
    _defaultValueFormatter.setup(digits);
  }

  double getMeasuredHeight() {
    return _size == null ? 0.0 : _size.height;
  }

  double getMeasuredWidth() {
    return _size == null ? 0.0 : _size.width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;

    if (!_isInit) {
      MPPointF c = getCenter(size);
      _infoPaint.layout();
      _infoPaint.paint(canvas,
          Offset(c.x - _infoPaint.width / 2, c.y - _infoPaint.height / 2));
      return;
    }

    _viewPortHandler?.setChartDimens(size.width, size.height);

    if (!_offsetsCalculated) {
      calculateOffsets();
      _offsetsCalculated = true;
    }

    onPaint(canvas, size);
  }

  void onPaint(Canvas canvas, Size size);

  /// Draws the description text in the bottom right corner of the chart (per default)
  void drawDescription(Canvas c, Size size) {
    // check if description should be drawn
    if (_description != null && _description.enabled) {
      MPPointF position = _description.position;
      double x, y;
      // if no position specified, draw on default position
      if (position == null) {
        x = size.width - _viewPortHandler.offsetRight() - _description.xOffset;
        y = size.height -
            _viewPortHandler.offsetBottom() -
            _description.yOffset;
      } else {
        x = position.x;
        y = position.y;
      }
      _descPaint.paint(c, Offset(x, y));
    }
  }

  /// Returns true if there are values to highlight, false if there are no
  /// values to highlight. Checks if the highlight array is null, has a length
  /// of zero or if the first object is null.
  ///
  /// @return
  bool valuesToHighlight() {
    var res = _indicesToHighlight == null ||
            _indicesToHighlight.length <= 0 ||
            _indicesToHighlight[0] == null
        ? false
        : true;
    return res;
  }

  /// Highlights the values at the given indices in the given DataSets. Provide
  /// null or an empty array to undo all highlighting. This should be used to
  /// programmatically highlight values.
  /// This method *will not* call the listener.
  ///
  /// @param highs
  void highlightValues(List<Highlight> highs) {
    // set the indices to highlight
    _indicesToHighlight = highs;
  }

  /// Highlights any y-value at the given x-value in the given DataSet.
  /// Provide -1 as the dataSetIndex to undo all highlighting.
  /// This method will call the listener.
  /// @param x The x-value to highlight
  /// @param dataSetIndex The dataset index to search in
  void highlightValue1(double x, int dataSetIndex) {
    highlightValue3(x, dataSetIndex, true);
  }

  /// Highlights the value at the given x-value and y-value in the given DataSet.
  /// Provide -1 as the dataSetIndex to undo all highlighting.
  /// This method will call the listener.
  /// @param x The x-value to highlight
  /// @param y The y-value to highlight. Supply `NaN` for "any"
  /// @param dataSetIndex The dataset index to search in
  void highlightValue2(double x, double y, int dataSetIndex) {
    highlightValue4(x, y, dataSetIndex, true);
  }

  /// Highlights any y-value at the given x-value in the given DataSet.
  /// Provide -1 as the dataSetIndex to undo all highlighting.
  /// @param x The x-value to highlight
  /// @param dataSetIndex The dataset index to search in
  /// @param callListener Should the listener be called for this change
  void highlightValue3(double x, int dataSetIndex, bool callListener) {
    highlightValue4(x, double.nan, dataSetIndex, callListener);
  }

  /// Highlights any y-value at the given x-value in the given DataSet.
  /// Provide -1 as the dataSetIndex to undo all highlighting.
  /// @param x The x-value to highlight
  /// @param y The y-value to highlight. Supply `NaN` for "any"
  /// @param dataSetIndex The dataset index to search in
  /// @param callListener Should the listener be called for this change
  void highlightValue4(
      double x, double y, int dataSetIndex, bool callListener) {
    if (dataSetIndex < 0 || dataSetIndex >= _data.getDataSetCount()) {
      highlightValue6(null, callListener);
    } else {
      highlightValue6(
          Highlight(x: x, y: y, dataSetIndex: dataSetIndex), callListener);
    }
  }

  /// Highlights the values represented by the provided Highlight object
  /// This method *will not* call the listener.
  ///
  /// @param highlight contains information about which entry should be highlighted
  void highlightValue5(Highlight highlight) {
    highlightValue6(highlight, false);
  }

  /// Highlights the value selected by touch gesture. Unlike
  /// highlightValues(...), this generates a callback to the
  /// OnChartValueSelectedListener.
  ///
  /// @param high         - the highlight object
  /// @param callListener - call the listener
  void highlightValue6(Highlight high, bool callListener) {
    Entry e;

    if (high == null) {
      _indicesToHighlight = null;
    } else {
      e = _data.getEntryForHighlight(high);
      if (e == null) {
        _indicesToHighlight = null;
        high = null;
      } else {
        // set the indices to highlight
        _indicesToHighlight = List()..add(high);
      }
    }

    if (callListener && _selectionListener != null) {
      if (!valuesToHighlight())
        _selectionListener?.onNothingSelected();
      else {
        // notify the listener
        _selectionListener?.onValueSelected(e, high);
      }
    }
  }

  /// Returns the Highlight object (contains x-index and DataSet index) of the
  /// selected value at the given touch point inside the Line-, Scatter-, or
  /// CandleStick-Chart.
  ///
  /// @param x
  /// @param y
  /// @return
  Highlight getHighlightByTouchPoint(double x, double y) {
    if (_data == null) {
      return null;
    } else {
      return highlighter.getHighlight(x, y);
    }
  }

  /// draws all MarkerViews on the highlighted positions
  void drawMarkers(Canvas canvas) {
    if (_marker == null || !_drawMarkers || !valuesToHighlight()) return;

    for (int i = 0; i < _indicesToHighlight.length; i++) {
      Highlight highlight = _indicesToHighlight[i];

      IDataSet set = _data.getDataSetByIndex(highlight.dataSetIndex);

      Entry e = _data.getEntryForHighlight(_indicesToHighlight[i]);
      int entryIndex = set.getEntryIndex2(e);
      // make sure entry not null
      if (e == null || entryIndex > set.getEntryCount() * _animator.getPhaseX())
        continue;

      List<double> pos = getMarkerPosition(highlight);

      // check bounds
      if (!_viewPortHandler.isInBounds(pos[0], pos[1])) continue;

      // callbacks to update the content
      _marker.refreshContent(e, highlight);

      // draw the marker
      _marker.draw(canvas, pos[0], pos[1]);
    }
  }

  /// Returns the actual position in pixels of the MarkerView for the given
  /// Highlight object.
  ///
  /// @param high
  /// @return
  List<double> getMarkerPosition(Highlight high) {
    return List<double>()..add(high.drawX)..add(high.drawY);
  }

  @override
  ChartData<IDataSet<Entry>> getData() {
    return _data;
  }

  @override
  ValueFormatter getDefaultValueFormatter() {
    return _defaultValueFormatter;
  }

  @override
  double getMaxHighlightDistance() {
    return _maxHighlightDistance;
  }

  /// Returns a recyclable MPPointF instance.
  /// Returns the center point of the chart (the whole View) in pixels.
  ///
  /// @return
  MPPointF getCenter(Size size) {
    return MPPointF.getInstance1(size.width / 2, size.height / 2);
  }

  /// Returns a recyclable MPPointF instance.
  /// Returns the center of the chart taking offsets under consideration.
  /// (returns the center of the content rectangle)
  ///
  /// @return
  @override
  MPPointF getCenterOffsets() {
    return _viewPortHandler.getContentCenter();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

  void reassemble() {
    _offsetsCalculated = false;
  }
}
