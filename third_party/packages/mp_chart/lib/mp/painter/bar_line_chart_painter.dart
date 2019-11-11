import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_line_scatter_candle_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/bar_line_scatter_candle_bubble_data_provider.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/enums/legend_horizontal_alignment.dart';
import 'package:mp_chart/mp/core/enums/legend_orientation.dart';
import 'package:mp_chart/mp/core/enums/legend_vertical_alignment.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/highlight/chart_hightlighter.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/legend/legend.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/render/legend_renderer.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/matrix4_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/painter.dart';

abstract class BarLineChartBasePainter<
T extends BarLineScatterCandleBubbleData<
    IBarLineScatterCandleBubbleDataSet<Entry>>> extends ChartPainter<T>
    implements BarLineScatterCandleBubbleDataProvider {
  /// the maximum number of entries to which values will be drawn
  /// (entry numbers greater than this value will cause value-labels to disappear)
  final int _maxVisibleCount;

  /// flag that indicates if auto scaling on the y axis is enabled
  final bool _autoScaleMinMaxEnabled;

  /// flag that indicates if pinch-zoom is enabled. if true, both x and y axis
  /// can be scaled with 2 fingers, if false, x and y axis can be scaled
  /// separately
  final bool _pinchZoomEnabled;

  /// flag that indicates if double tap zoom is enabled or not
  final bool _doubleTapToZoomEnabled;

  /// flag that indicates if highlighting per dragging over a fully zoomed out
  /// chart is enabled
  final bool _highlightPerDragEnabled;

  /// if true, dragging is enabled for the chart
  final bool _dragXEnabled;
  final bool _dragYEnabled;

  final bool _scaleXEnabled;
  final bool _scaleYEnabled;

  /// paint object for the (by default) lightgrey background of the grid
  final Paint _gridBackgroundPaint;

  final Paint _backgroundPaint;

  final Paint _borderPaint;

  /// flag indicating if the grid background should be drawn or not
  final bool _drawGridBackground;

  final bool _drawBorders;

  final bool _clipValuesToContent;

  /// Sets the minimum offset (padding) around the chart, defaults to 15
  final double _minOffset;

  /// flag indicating if the chart should stay at the same position after a rotation. Default is false.
  final bool _keepPositionOnRotation;

  /// the listener for user drawing on the chart
  final OnDrawListener _drawListener;

  /// the object representing the labels on the left y-axis
  final YAxis _axisLeft;

  /// the object representing the labels on the right y-axis
  final YAxis _axisRight;

  final YAxisRenderer _axisRendererLeft;
  final YAxisRenderer _axisRendererRight;

  final Transformer _leftAxisTransformer;
  final Transformer _rightAxisTransformer;

  final XAxisRenderer _xAxisRenderer;

  /// flag that indicates if a custom viewport offset has been set
  bool _customViewPortEnabled;

  /// CODE BELOW THIS RELATED TO SCALING AND GESTURES AND MODIFICATION OF THE
  /// VIEWPORT
  final Matrix4 _zoomMatrixBuffer;

  /////////////////////////////////

  Rect _offsetsBuffer = Rect.zero;

  YAxis get axisLeft => _axisLeft;

  YAxis get axisRight => _axisRight;

  YAxisRenderer get axisRendererLeft => _axisRendererLeft;

  YAxisRenderer get axisRendererRight => _axisRendererRight;

  double get minOffset => _minOffset;

  Transformer get leftAxisTransformer => _leftAxisTransformer;

  Transformer get rightAxisTransformer => _rightAxisTransformer;

  bool get highlightPerDragEnabled => _highlightPerDragEnabled;

  bool get dragXEnabled => _dragXEnabled;

  bool get dragYEnabled => _dragYEnabled;

  bool get scaleXEnabled => _scaleXEnabled;

  bool get scaleYEnabled => _scaleYEnabled;

  bool get doubleTapToZoomEnabled => _doubleTapToZoomEnabled;

  BarLineChartBasePainter(T data,
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
      OnChartValueSelectedListener selectedListener,
      int maxVisibleCount,
      bool autoScaleMinMaxEnabled,
      bool pinchZoomEnabled,
      bool doubleTapToZoomEnabled,
      bool highlightPerDragEnabled,
      bool dragXEnabled,
      bool dragYEnabled,
      bool scaleXEnabled,
      bool scaleYEnabled,
      Paint gridBackgroundPaint,
      Paint borderPaint,
      bool drawGridBackground,
      bool drawBorders,
      bool clipValuesToContent,
      double minOffset,
      bool keepPositionOnRotation,
      OnDrawListener drawListener,
      YAxis axisLeft,
      YAxis axisRight,
      YAxisRenderer axisRendererLeft,
      YAxisRenderer axisRendererRight,
      Transformer leftAxisTransformer,
      Transformer rightAxisTransformer,
      XAxisRenderer xAxisRenderer,
      Matrix4 zoomMatrixBuffer,
      bool customViewPortEnabled,
      Paint backgroundPaint)
      : _keepPositionOnRotation = keepPositionOnRotation,
        _leftAxisTransformer = leftAxisTransformer,
        _rightAxisTransformer = rightAxisTransformer,
        _zoomMatrixBuffer = zoomMatrixBuffer,
        _pinchZoomEnabled = pinchZoomEnabled,
        _xAxisRenderer = xAxisRenderer,
        _axisRendererLeft = axisRendererLeft,
        _axisRendererRight = axisRendererRight,
        _autoScaleMinMaxEnabled = autoScaleMinMaxEnabled,
        _minOffset = minOffset,
        _clipValuesToContent = clipValuesToContent,
        _drawBorders = drawBorders,
        _drawGridBackground = drawGridBackground,
        _doubleTapToZoomEnabled = doubleTapToZoomEnabled,
        _scaleXEnabled = scaleXEnabled,
        _scaleYEnabled = scaleYEnabled,
        _dragXEnabled = dragXEnabled,
        _dragYEnabled = dragYEnabled,
        _highlightPerDragEnabled = highlightPerDragEnabled,
        _maxVisibleCount = maxVisibleCount,
        _customViewPortEnabled = customViewPortEnabled,
        _axisLeft = axisLeft,
        _axisRight = axisRight,
        _drawListener = drawListener,
        _gridBackgroundPaint = gridBackgroundPaint,
        _borderPaint = borderPaint,
        _backgroundPaint = backgroundPaint,
        super(
          data,
          animator,
          viewPortHandler,
          maxHighlightDistance,
          highLightPerTapEnabled,
          extraLeftOffset,
          extraTopOffset,
          extraRightOffset,
          extraBottomOffset,
          marker,
          desc,
          drawMarkers,
          infoPainter,
          descPainter,
          xAxis,
          legend,
          legendRenderer,
          rendererSettingFunction,
          selectedListener);

  @override
  void initDefaultWithData() {
    super.initDefaultWithData();
    highlighter = ChartHighlighter(this);
  }

  @override
  void onPaint(Canvas canvas, Size size) {
    if (_backgroundPaint != null) {
      canvas.drawRect(
          Rect.fromLTRB(0, 0, size.width, size.height), _backgroundPaint);
    }

    // execute all drawing commands
    drawGridBackground(canvas);

    _xAxisRenderer.renderAxisLine(canvas);
    _axisRendererLeft.renderAxisLine(canvas);
    _axisRendererRight.renderAxisLine(canvas);

    if (xAxis.drawGridLinesBehindData) _xAxisRenderer.renderGridLines(canvas);

    if (_axisLeft.drawGridLinesBehindData)
      _axisRendererLeft.renderGridLines(canvas);

    if (_axisRight.drawGridLinesBehindData)
      _axisRendererRight.renderGridLines(canvas);

    if (xAxis.enabled && xAxis.drawLimitLineBehindData)
      _xAxisRenderer.renderLimitLines(canvas);

    if (_axisLeft.enabled && _axisLeft.drawLimitLineBehindData)
      _axisRendererLeft.renderLimitLines(canvas);

    if (_axisRight.enabled && _axisRight.drawLimitLineBehindData)
      _axisRendererRight.renderLimitLines(canvas);

    // make sure the data cannot be drawn outside the content-rect
    canvas.save();
    canvas.clipRect(viewPortHandler.getContentRect());

    renderer.drawData(canvas);

    if (!xAxis.drawGridLinesBehindData) _xAxisRenderer.renderGridLines(canvas);

    if (!_axisLeft.drawGridLinesBehindData)
      _axisRendererLeft.renderGridLines(canvas);

    if (!_axisRight.drawGridLinesBehindData)
      _axisRendererRight.renderGridLines(canvas);

    // if highlighting is enabled
    if (valuesToHighlight())
      renderer.drawHighlighted(canvas, indicesToHighlight);

    // Removes clipping rectangle
    canvas.restore();

    renderer.drawExtras(canvas);

    if (xAxis.enabled && !xAxis.drawLimitLineBehindData)
      _xAxisRenderer.renderLimitLines(canvas);

    if (_axisLeft.enabled && !_axisLeft.drawLimitLineBehindData)
      _axisRendererLeft.renderLimitLines(canvas);

    if (_axisRight.enabled && !_axisRight.drawLimitLineBehindData)
      _axisRendererRight.renderLimitLines(canvas);

    _xAxisRenderer.renderAxisLabels(canvas);
    _axisRendererLeft.renderAxisLabels(canvas);
    _axisRendererRight.renderAxisLabels(canvas);

    if (_clipValuesToContent) {
      canvas.save();
      canvas.clipRect(viewPortHandler.getContentRect());

      renderer.drawValues(canvas);

      canvas.restore();
    } else {
      renderer.drawValues(canvas);
    }

    legendRenderer.renderLegend(canvas);

    drawDescription(canvas, size);

    drawMarkers(canvas);
  }

  void prepareValuePxMatrix() {
    _rightAxisTransformer.prepareMatrixValuePx(xAxis.axisMinimum,
        xAxis.axisRange, _axisRight.axisRange, _axisRight.axisMinimum);

    _leftAxisTransformer.prepareMatrixValuePx(xAxis.axisMinimum,
        xAxis.axisRange, _axisLeft.axisRange, _axisLeft.axisMinimum);
  }

  void prepareOffsetMatrix() {
    _rightAxisTransformer.prepareMatrixOffset(_axisRight.inverted);
    _leftAxisTransformer.prepareMatrixOffset(_axisLeft.inverted);
  }

  /// Performs auto scaling of the axis by recalculating the minimum and maximum y-values based on the entries currently in view.
  void autoScale() {
    // todo autoScale
  }

  @override
  void calcMinMax() {
    xAxis.calculate(getData().xMin, getData().xMax);
    // calculate axis range (min / max) according to provided data
    _axisLeft.calculate(getData().getYMin2(AxisDependency.LEFT),
        getData().getYMax2(AxisDependency.LEFT));
    _axisRight.calculate(getData().getYMin2(AxisDependency.RIGHT),
        getData().getYMax2(AxisDependency.RIGHT));
  }

  Rect calculateLegendOffsets(Rect offsets) {
    offsets = Rect.fromLTRB(0.0, 0.0, 0.0, 0.0);
    // setup offsets for legend
    if (legend != null && legend.enabled && !legend.drawInside) {
      switch (legend.orientation) {
        case LegendOrientation.VERTICAL:
          switch (legend.horizontalAlignment) {
            case LegendHorizontalAlignment.LEFT:
              offsets = Rect.fromLTRB(
                  min(
                      legend.neededWidth,
                      viewPortHandler.getChartWidth() *
                          legend.maxSizePercent) +
                      legend.xOffset,
                  0.0,
                  0.0,
                  0.0);
              break;

            case LegendHorizontalAlignment.RIGHT:
              offsets = Rect.fromLTRB(
                  0.0,
                  0.0,
                  min(
                      legend.neededWidth,
                      viewPortHandler.getChartWidth() *
                          legend.maxSizePercent) +
                      legend.xOffset,
                  0.0);
              break;

            case LegendHorizontalAlignment.CENTER:
              switch (legend.verticalAlignment) {
                case LegendVerticalAlignment.TOP:
                  offsets = Rect.fromLTRB(
                      0.0,
                      min(
                          legend.neededHeight,
                          viewPortHandler.getChartHeight() *
                              legend.maxSizePercent) +
                          legend.yOffset,
                      0.0,
                      0.0);
                  break;

                case LegendVerticalAlignment.BOTTOM:
                  offsets = Rect.fromLTRB(
                      0.0,
                      0.0,
                      0.0,
                      min(
                          legend.neededHeight,
                          viewPortHandler.getChartHeight() *
                              legend.maxSizePercent) +
                          legend.yOffset);
                  break;

                default:
                  break;
              }
          }

          break;

        case LegendOrientation.HORIZONTAL:
          switch (legend.verticalAlignment) {
            case LegendVerticalAlignment.TOP:
              offsets = Rect.fromLTRB(
                  0.0,
                  min(
                      legend.neededHeight,
                      viewPortHandler.getChartHeight() *
                          legend.maxSizePercent) +
                      legend.yOffset,
                  0.0,
                  0.0);
              break;

            case LegendVerticalAlignment.BOTTOM:
              offsets = Rect.fromLTRB(
                  0.0,
                  0.0,
                  0.0,
                  min(
                      legend.neededHeight,
                      viewPortHandler.getChartHeight() *
                          legend.maxSizePercent) +
                      legend.yOffset);
              break;

            default:
              break;
          }
          break;
      }
    }
    return offsets;
  }

  void compute() {
    if (_autoScaleMinMaxEnabled) {
      autoScale();
    }

    if (_axisLeft.enabled) {
      _axisRendererLeft.computeAxis(
          _axisLeft.axisMinimum, _axisLeft.axisMaximum, _axisLeft.inverted);
    }

    if (_axisRight.enabled) {
      _axisRendererRight.computeAxis(
          _axisRight.axisMinimum, _axisRight.axisMaximum, _axisRight.inverted);
    }

    if (xAxis.enabled) {
      _xAxisRenderer.computeAxis(xAxis.axisMinimum, xAxis.axisMaximum, false);
    }
  }

  @override
  void calculateOffsets() {
    if (legend != null) legendRenderer.computeLegend(getData());
    renderer?.initBuffers();
    calcMinMax();
    compute();

    if (!_customViewPortEnabled) {
      double offsetLeft = 0,
          offsetRight = 0,
          offsetTop = 0,
          offsetBottom = 0;

      _offsetsBuffer = calculateLegendOffsets(_offsetsBuffer);

      offsetLeft += _offsetsBuffer.left;
      offsetTop += _offsetsBuffer.top;
      offsetRight += _offsetsBuffer.right;
      offsetBottom += _offsetsBuffer.bottom;

      // offsets for y-labels
      if (_axisLeft.needsOffset()) {
        offsetLeft +=
            _axisLeft.getRequiredWidthSpace(_axisRendererLeft.axisLabelPaint);
      }

      if (_axisRight.needsOffset()) {
        offsetRight +=
            _axisRight.getRequiredWidthSpace(_axisRendererRight.axisLabelPaint);
      }

      if (xAxis.enabled && xAxis.drawLabels) {
        double xLabelHeight = xAxis.labelRotatedHeight +
            xAxis.yOffset +
            xAxis.getRequiredHeightSpace(_xAxisRenderer.axisLabelPaint);

        // offsets for x-labels
        if (xAxis.position == XAxisPosition.BOTTOM) {
          offsetBottom += xLabelHeight;
        } else if (xAxis.position == XAxisPosition.TOP) {
          offsetTop += xLabelHeight;
        } else if (xAxis.position == XAxisPosition.BOTH_SIDED) {
          offsetBottom += xLabelHeight;
          offsetTop += xLabelHeight;
        }
      }

      offsetTop += extraTopOffset;
      offsetRight += extraRightOffset;
      offsetBottom += extraBottomOffset;
      offsetLeft += extraLeftOffset;

      double minOffset = Utils.convertDpToPixel(_minOffset);

      viewPortHandler.restrainViewPort(
          max(minOffset, offsetLeft),
          max(minOffset, offsetTop),
          max(minOffset, offsetRight),
          max(minOffset, offsetBottom));
    }

    prepareOffsetMatrix();
    prepareValuePxMatrix();
  }

  /// draws the grid background
  void drawGridBackground(Canvas c) {
    if (_drawGridBackground) {
      // draw the grid background
      c.drawRect(viewPortHandler.getContentRect(), _gridBackgroundPaint);
    }

    if (_drawBorders) {
      c.drawRect(viewPortHandler.getContentRect(), _borderPaint);
    }
  }

  /// Returns the Transformer class that contains all matrices and is
  /// responsible for transforming values into pixels on the screen and
  /// backwards.
  ///
  /// @return
  Transformer getTransformer(AxisDependency which) {
    if (which == AxisDependency.LEFT)
      return _leftAxisTransformer;
    else
      return _rightAxisTransformer;
  }

  /// Zooms in or out by the given scale factor. x and y are the coordinates
  /// (in pixels) of the zoom center.
  ///
  /// @param scaleX if < 1f --> zoom out, if > 1f --> zoom in
  /// @param scaleY if < 1f --> zoom out, if > 1f --> zoom in
  /// @param x
  /// @param y
  void zoom(double scaleX, double scaleY, double x, double y) {
    if (scaleX.isInfinite ||
        scaleX.isNaN ||
        scaleY.isInfinite ||
        scaleY.isNaN) {
      return;
    }

    viewPortHandler.zoom4(scaleX, scaleY, x, -y, _zoomMatrixBuffer);
    viewPortHandler.refresh(_zoomMatrixBuffer);
  }

  void translate(double dx, double dy) {
    Matrix4Utils.postTranslate(viewPortHandler.matrixTouch, dx, dy);
    viewPortHandler.limitTransAndScale(
        viewPortHandler.matrixTouch, viewPortHandler.contentRect);
  }

  /// Sets the size of the area (range on the y-axis) that should be maximum
  /// visible at once.
  ///
  /// @param maxYRange the maximum visible range on the y-axis
  /// @param axis      the axis for which this limit should apply
  void setVisibleYRangeMaximum(double maxYRange, AxisDependency axis) {
    double yScale = getAxisRange(axis) / maxYRange;
    viewPortHandler.setMinimumScaleY(yScale);
  }

  /// Sets the size of the area (range on the y-axis) that should be minimum visible at once, no further zooming in possible.
  ///
  /// @param minYRange
  /// @param axis      the axis for which this limit should apply
  void setVisibleYRangeMinimum(double minYRange, AxisDependency axis) {
    double yScale = getAxisRange(axis) / minYRange;
    viewPortHandler.setMaximumScaleY(yScale);
  }

  /// Limits the maximum and minimum y range that can be visible by pinching and zooming.
  ///
  /// @param minYRange
  /// @param maxYRange
  /// @param axis
  void setVisibleYRange(double minYRange, double maxYRange,
      AxisDependency axis) {
    double minScale = getAxisRange(axis) / minYRange;
    double maxScale = getAxisRange(axis) / maxYRange;
    viewPortHandler.setMinMaxScaleY(minScale, maxScale);
  }

  /**
   * ################ ################ ################ ################
   */
  /** CODE BELOW IS GETTERS AND SETTERS */

  /// Returns the range of the specified axis.
  ///
  /// @param axis
  /// @return
  double getAxisRange(AxisDependency axis) {
    if (axis == AxisDependency.LEFT)
      return _axisLeft.axisRange;
    else
      return _axisRight.axisRange;
  }

  List<double> mGetPositionBuffer = List(2);

  /// Returns a recyclable MPPointF instance.
  /// Returns the position (in pixels) the provided Entry has inside the chart
  /// view or null, if the provided Entry is null.
  ///
  /// @param e
  /// @return
  MPPointF getPosition(Entry e, AxisDependency axis) {
    if (e == null) return null;

    mGetPositionBuffer[0] = e.x;
    mGetPositionBuffer[1] = e.y;

    getTransformer(axis).pointValuesToPixel(mGetPositionBuffer);

    return MPPointF.getInstance1(mGetPositionBuffer[0], mGetPositionBuffer[1]);
  }

  /// Sets the color for the background of the chart-drawing area (everything
  /// behind the grid lines).
  ///
  /// @param color
  void setGridBackgroundColor(Color color) {
    _gridBackgroundPaint..color = color;
  }

  /// Sets the width of the border lines in dp.
  ///
  /// @param width
  void setBorderWidth(double width) {
    _borderPaint..strokeWidth = Utils.convertDpToPixel(width);
  }

  /// Sets the color of the chart border lines.
  ///
  /// @param color
  void setBorderColor(Color color) {
    _borderPaint..color = color;
  }

  /// Returns a recyclable MPPointD instance
  /// Returns the x and y values in the chart at the given touch point
  /// (encapsulated in a MPPointD). This method transforms pixel coordinates to
  /// coordinates / values in the chart. This is the opposite method to
  /// getPixelForValues(...).
  ///
  /// @param x
  /// @param y
  /// @return
  MPPointD getValuesByTouchPoint1(double x, double y, AxisDependency axis) {
    MPPointD result = MPPointD.getInstance1(0, 0);
    getValuesByTouchPoint2(x, y, axis, result);
    return result;
  }

  void getValuesByTouchPoint2(double x, double y, AxisDependency axis,
      MPPointD outputPoint) {
    getTransformer(axis).getValuesByTouchPoint2(x, y, outputPoint);
  }

  /// Returns a recyclable MPPointD instance
  /// Transforms the given chart values into pixels. This is the opposite
  /// method to getValuesByTouchPoint(...).
  ///
  /// @param x
  /// @param y
  /// @return
  MPPointD getPixelForValues(double x, double y, AxisDependency axis) {
    return getTransformer(axis).getPixelForValues(x, y);
  }

  /// returns the Entry object displayed at the touched position of the chart
  ///
  /// @param x
  /// @param y
  /// @return
  Entry getEntryByTouchPoint(double x, double y) {
    Highlight h = getHighlightByTouchPoint(x, y);
    if (h != null) {
      return getData().getEntryForHighlight(h);
    }
    return null;
  }

  /// returns the DataSet object displayed at the touched position of the chart
  ///
  /// @param x
  /// @param y
  /// @return
  IBarLineScatterCandleBubbleDataSet getDataSetByTouchPoint(double x,
      double y) {
    Highlight h = getHighlightByTouchPoint(x, y);
    if (h != null) {
      return getData().getDataSetByIndex(h.dataSetIndex);
    }
    return null;
  }

  /// buffer for storing lowest visible x point
  MPPointD posForGetLowestVisibleX = MPPointD.getInstance1(0, 0);

  /// Returns the lowest x-index (value on the x-axis) that is still visible on
  /// the chart.
  ///
  /// @return
  @override
  double getLowestVisibleX() {
    getTransformer(AxisDependency.LEFT).getValuesByTouchPoint2(
        viewPortHandler.contentLeft(),
        viewPortHandler.contentBottom(),
        posForGetLowestVisibleX);
    double result = max(xAxis.axisMinimum, posForGetLowestVisibleX.x);
    return result;
  }

  /// buffer for storing highest visible x point
  MPPointD posForGetHighestVisibleX = MPPointD.getInstance1(0, 0);

  /// Returns the highest x-index (value on the x-axis) that is still visible
  /// on the chart.
  ///
  /// @return
  @override
  double getHighestVisibleX() {
    getTransformer(AxisDependency.LEFT).getValuesByTouchPoint2(
        viewPortHandler.contentRight(),
        viewPortHandler.contentBottom(),
        posForGetHighestVisibleX);
    double result = min(xAxis.axisMaximum, posForGetHighestVisibleX.x);
    return result;
  }

  /// Returns the range visible on the x-axis.
  ///
  /// @return
  double getVisibleXRange() {
    return (getHighestVisibleX() - getLowestVisibleX()).abs();
  }

  /// returns the current x-scale factor
  double getScaleX() {
    if (viewPortHandler == null)
      return 1;
    else
      return viewPortHandler.getScaleX();
  }

  /// returns the current y-scale factor
  double getScaleY() {
    if (viewPortHandler == null)
      return 1;
    else
      return viewPortHandler.getScaleY();
  }

  /// if the chart is fully zoomed out, return true
  ///
  /// @return
  bool isFullyZoomedOut() {
    return viewPortHandler.isFullyZoomedOut();
  }

  /// Returns the y-axis object to the corresponding AxisDependency. In the
  /// horizontal bar-chart, LEFT == top, RIGHT == BOTTOM
  ///
  /// @param axis
  /// @return
  YAxis getAxis(AxisDependency axis) {
    if (axis == AxisDependency.LEFT)
      return _axisLeft;
    else
      return _axisRight;
  }

  @override
  bool isInverted(AxisDependency axis) {
    return getAxis(axis).inverted;
  }

  /// Set an offset in dp that allows the user to drag the chart over it's
  /// bounds on the x-axis.
  ///
  /// @param offset
  void setDragOffsetX(double offset) {
    viewPortHandler.setDragOffsetX(offset);
  }

  /// Set an offset in dp that allows the user to drag the chart over it's
  /// bounds on the y-axis.
  ///
  /// @param offset
  void setDragOffsetY(double offset) {
    viewPortHandler.setDragOffsetY(offset);
  }

  /// Returns true if both drag offsets (x and y) are zero or smaller.
  ///
  /// @return
  bool hasNoDragOffset() {
    return viewPortHandler.hasNoDragOffset();
  }

  @override
  double getYChartMax() {
    return max(_axisLeft.axisMaximum, _axisRight.axisMaximum);
  }

  @override
  double getYChartMin() {
    return min(_axisLeft.axisMinimum, _axisRight.axisMinimum);
  }

  @override
  int getMaxVisibleCount() {
    return _maxVisibleCount;
  }

  @override
  BarLineScatterCandleBubbleData getData() {
    return super.getData();
  }

  /// Returns true if either the left or the right or both axes are inverted.
  ///
  /// @return
  bool isAnyAxisInverted() {
    if (_axisLeft.inverted) return true;
    if (_axisRight.inverted) return true;
    return false;
  }
}
