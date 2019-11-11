import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/controller/controller.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/painter/bar_line_chart_painter.dart';

abstract class BarLineScatterCandleBubbleController<P extends BarLineChartBasePainter>
    extends Controller<P> {
  int maxVisibleCount;
  bool autoScaleMinMaxEnabled;
  bool doubleTapToZoomEnabled;
  bool highlightPerDragEnabled;
  bool dragXEnabled;
  bool dragYEnabled;
  bool scaleXEnabled;
  bool scaleYEnabled;
  bool drawGridBackground;
  bool drawBorders;
  bool clipValuesToContent;
  double minOffset;
  OnDrawListener drawListener;
  YAxis axisLeft;
  YAxis axisRight;
  YAxisRenderer axisRendererLeft;
  YAxisRenderer axisRendererRight;
  Transformer leftAxisTransformer;
  Transformer rightAxisTransformer;
  XAxisRenderer xAxisRenderer;
  bool customViewPortEnabled;
  Matrix4 zoomMatrixBuffer;
  bool pinchZoomEnabled;
  bool keepPositionOnRotation;

  Paint gridBackgroundPaint;
  Paint borderPaint;

  Paint backgroundPaint;
  Color gridBackColor;
  Color borderColor;
  Color backgroundColor;
  double borderStrokeWidth;

  AxisLeftSettingFunction axisLeftSettingFunction;
  AxisRightSettingFunction axisRightSettingFunction;

  BarLineScatterCandleBubbleController({
    this.maxVisibleCount = 100,
    this.autoScaleMinMaxEnabled = true,
    this.doubleTapToZoomEnabled = true,
    this.highlightPerDragEnabled = true,
    this.dragXEnabled = true,
    this.dragYEnabled = true,
    this.scaleXEnabled = true,
    this.scaleYEnabled = true,
    this.drawGridBackground = false,
    this.drawBorders = false,
    this.clipValuesToContent = false,
    this.minOffset = 30.0,
    this.drawListener,
    this.axisLeft,
    this.axisRight,
    this.axisRendererLeft,
    this.axisRendererRight,
    this.leftAxisTransformer,
    this.rightAxisTransformer,
    this.xAxisRenderer,
    this.customViewPortEnabled = false,
    this.zoomMatrixBuffer,
    this.pinchZoomEnabled = true,
    this.keepPositionOnRotation = false,
    this.gridBackgroundPaint,
    this.borderPaint,
    this.backgroundPaint,
    this.gridBackColor,
    this.borderColor,
    this.backgroundColor,
    this.borderStrokeWidth = 1.0,
    this.axisLeftSettingFunction,
    this.axisRightSettingFunction,
    IMarker marker,
    Description description,
    String noDataText = "No chart data available.",
    XAxisSettingFunction xAxisSettingFunction,
    LegendSettingFunction legendSettingFunction,
    DataRendererSettingFunction rendererSettingFunction,
    OnChartValueSelectedListener selectionListener,
    double maxHighlightDistance = 100.0,
    bool highLightPerTapEnabled = true,
    double extraTopOffset = 0.0,
    double extraRightOffset = 0.0,
    double extraBottomOffset = 0.0,
    double extraLeftOffset = 0.0,
    bool drawMarkers = true,
    double descTextSize = 12,
    double infoTextSize = 12,
    Color descTextColor,
    Color infoTextColor,
  }) : super(
            marker: marker,
            description: description,
            noDataText: noDataText,
            xAxisSettingFunction: xAxisSettingFunction,
            legendSettingFunction: legendSettingFunction,
            rendererSettingFunction: rendererSettingFunction,
            selectionListener: selectionListener,
            maxHighlightDistance: maxHighlightDistance,
            highLightPerTapEnabled: highLightPerTapEnabled,
            extraTopOffset: extraTopOffset,
            extraRightOffset: extraRightOffset,
            extraBottomOffset: extraBottomOffset,
            extraLeftOffset: extraLeftOffset,
            drawMarkers: drawMarkers,
            descTextSize: descTextSize,
            infoTextSize: infoTextSize,
            descTextColor: descTextColor,
            infoTextColor: infoTextColor);

  OnDrawListener initDrawListener() {
    return null;
  }

  YAxis initAxisLeft() => YAxis(position: AxisDependency.LEFT);

  YAxis initAxisRight() => YAxis(position: AxisDependency.RIGHT);

  Transformer initLeftAxisTransformer() => Transformer(viewPortHandler);

  Transformer initRightAxisTransformer() => Transformer(viewPortHandler);

  YAxisRenderer initAxisRendererLeft() =>
      YAxisRenderer(viewPortHandler, axisLeft, leftAxisTransformer);

  YAxisRenderer initAxisRendererRight() =>
      YAxisRenderer(viewPortHandler, axisRight, rightAxisTransformer);

  XAxisRenderer initXAxisRenderer() =>
      XAxisRenderer(viewPortHandler, xAxis, leftAxisTransformer);

  @override
  void doneBeforePainterInit() {
    super.doneBeforePainterInit();
    gridBackgroundPaint = Paint()
      ..color = gridBackColor == null
          ? Color.fromARGB(255, 240, 240, 240)
          : gridBackColor
      ..style = PaintingStyle.fill;

    borderPaint = Paint()
      ..color = borderColor == null ? ColorUtils.BLACK : borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = Utils.convertDpToPixel(borderStrokeWidth);

    backgroundPaint = Paint()
      ..color = backgroundColor == null ? ColorUtils.WHITE : backgroundColor;

    drawListener ??= initDrawListener();
    axisLeft = initAxisLeft();
    axisRight = initAxisRight();
    leftAxisTransformer ??= initLeftAxisTransformer();
    rightAxisTransformer ??= initRightAxisTransformer();
    zoomMatrixBuffer ??= initZoomMatrixBuffer();
    axisRendererLeft = initAxisRendererLeft();
    axisRendererRight = initAxisRendererRight();
    xAxisRenderer = initXAxisRenderer();
    if (axisLeftSettingFunction != null) {
      axisLeftSettingFunction(axisLeft, this);
    }
    if (axisRightSettingFunction != null) {
      axisRightSettingFunction(axisRight, this);
    }
  }

  P get painter => super.painter;

  void setViewPortOffsets(final double left, final double top,
      final double right, final double bottom) {
    customViewPortEnabled = true;
    viewPortHandler.restrainViewPort(left, top, right, bottom);
  }

  Matrix4 initZoomMatrixBuffer() => Matrix4.identity();

  /// Sets the minimum scale factor value to which can be zoomed out. 1f =
  /// fitScreen
  ///
  /// @param scaleX
  /// @param scaleY
  void setScaleMinima(double scaleX, double scaleY) {
    viewPortHandler.setMinimumScaleX(scaleX);
    viewPortHandler.setMinimumScaleY(scaleY);
  }

  /// Moves the left side of the current viewport to the specified x-position.
  /// This also refreshes the chart by calling invalidate().
  ///
  /// @param xValue
  void moveViewToX(double xValue) {
    List<double> pts = List();
    pts.add(xValue);
    pts.add(0.0);

    painter?.getTransformer(AxisDependency.LEFT)?.pointValuesToPixel(pts);
    viewPortHandler.centerViewPort(pts);
  }

  /// This will move the left side of the current viewport to the specified
  /// x-value on the x-axis, and center the viewport to the specified y value on the y-axis.
  /// This also refreshes the chart by calling invalidate().
  ///
  /// @param xValue
  /// @param yValue
  /// @param axis   - which axis should be used as a reference for the y-axis
  void moveViewTo(double xValue, double yValue, AxisDependency axis) {
    double yInView = getAxisRange(axis) / viewPortHandler.getScaleY();
    List<double> pts = List();
    pts.add(xValue);
    pts.add(yValue + yInView / 2);
    painter?.getTransformer(axis)?.pointValuesToPixel(pts);
    viewPortHandler.centerViewPort(pts);
  }

  /// This will move the left side of the current viewport to the specified x-value
  /// and center the viewport to the y value animated.
  /// This also refreshes the chart by calling invalidate().
  ///
  /// @param xValue
  /// @param yValue
  /// @param axis
  /// @param duration the duration of the animation in milliseconds
  void moveViewToAnimated(
      double xValue, double yValue, AxisDependency axis, int durationMillis) {
    MPPointD bounds = getValuesByTouchPoint(
        viewPortHandler.contentLeft(), viewPortHandler.contentTop(), axis);
    double yInView = getAxisRange(axis) / viewPortHandler.getScaleY();

    yValue = yValue + yInView / 2;
    List<double> pts = List();
    pts.add(xValue);
    pts.add(yValue);
    double xOrigin = bounds.x;
    double yOrigin = bounds.y;
    ChartAnimator(UpdateListener((x, y) {
      pts[0] = xOrigin + (xValue - xOrigin) * x;
      pts[1] = yOrigin + (yValue - yOrigin) * y;
      painter?.getTransformer(axis)?.pointValuesToPixel(pts);
      viewPortHandler.centerViewPort(pts);
      state?.setStateIfNotDispose();
    })).animateXY1(durationMillis, durationMillis);

    MPPointD.recycleInstance2(bounds);
  }

  /// Centers the viewport to the specified y value on the y-axis.
  /// This also refreshes the chart by calling invalidate().
  ///
  /// @param yValue
  /// @param axis   - which axis should be used as a reference for the y-axis
  void centerViewToY(double yValue, AxisDependency axis) {
    double valsInView = getAxisRange(axis) / viewPortHandler.getScaleY();
    List<double> pts = List();
    pts.add(0.0);
    pts.add(yValue + valsInView / 2);
    painter?.getTransformer(axis)?.pointValuesToPixel(pts);
    viewPortHandler.centerViewPort(pts);
  }

  /// This will move the center of the current viewport to the specified
  /// x and y value.
  /// This also refreshes the chart by calling invalidate().
  ///
  /// @param xValue
  /// @param yValue
  /// @param axis   - which axis should be used as a reference for the y axis
  void centerViewTo(double xValue, double yValue, AxisDependency axis) {
    double yInView = getAxisRange(axis) / viewPortHandler.getScaleY();
    double xInView = xAxis.axisRange / viewPortHandler.getScaleX();
    List<double> pts = List();
    pts.add(xValue - xInView / 2);
    pts.add(yValue + yInView / 2);
    painter?.getTransformer(axis)?.pointValuesToPixel(pts);
    viewPortHandler.centerViewPort(pts);
  }

  /// This will move the center of the current viewport to the specified
  /// x and y value animated.
  ///
  /// @param xValue
  /// @param yValue
  /// @param axis
  /// @param duration the duration of the animation in milliseconds
  void centerViewToAnimated(
      double xValue, double yValue, AxisDependency axis, int durationMillis) {
    MPPointD bounds = getValuesByTouchPoint(
        viewPortHandler.contentLeft(), viewPortHandler.contentTop(), axis);
    double yInView = getAxisRange(axis) / viewPortHandler.getScaleY();
    double xInView = xAxis.axisRange / viewPortHandler.getScaleX();

    xValue = xValue - xInView / 2;
    yValue = yValue + yInView / 2;
    List<double> pts = List();
    pts.add(xValue);
    pts.add(yValue);
    double xOrigin = bounds.x;
    double yOrigin = bounds.y;
    ChartAnimator(UpdateListener((x, y) {
      pts[0] = xOrigin + (xValue - xOrigin) * x;
      pts[1] = yOrigin + (yValue - yOrigin) * y;
      painter?.getTransformer(axis)?.pointValuesToPixel(pts);
      viewPortHandler.centerViewPort(pts);
      state?.setStateIfNotDispose();
    })).animateXY1(durationMillis, durationMillis);

    MPPointD.recycleInstance2(bounds);
  }

  /// Sets the size of the area (range on the x-axis) that should be maximum
  /// visible at once (no further zooming out allowed). If this is e.g. set to
  /// 10, no more than a range of 10 on the x-axis can be viewed at once without
  /// scrolling.
  ///
  /// @param maxXRange The maximum visible range of x-values.
  void setVisibleXRangeMaximum(double maxXRange) {
    double xScale = xAxis.axisRange / (maxXRange);
    viewPortHandler.setMinimumScaleX(xScale);
  }

  /// Sets the size of the area (range on the x-axis) that should be minimum
  /// visible at once (no further zooming in allowed). If this is e.g. set to
  /// 10, no less than a range of 10 on the x-axis can be viewed at once without
  /// scrolling.
  ///
  /// @param minXRange The minimum visible range of x-values.
  void setVisibleXRangeMinimum(double minXRange) {
    double xScale = xAxis.axisRange / (minXRange);
    viewPortHandler.setMaximumScaleX(xScale);
  }

  /// Limits the maximum and minimum x range that can be visible by pinching and zooming. e.g. minRange=10, maxRange=100 the
  /// smallest range to be displayed at once is 10, and no more than a range of 100 values can be viewed at once without
  /// scrolling
  ///
  /// @param minXRange
  /// @param maxXRange
  void setVisibleXRange(double minXRange, double maxXRange) {
    double minScale = xAxis.axisRange / minXRange;
    double maxScale = xAxis.axisRange / maxXRange;
    viewPortHandler.setMinMaxScaleX(minScale, maxScale);
  }

  double getAxisRange(AxisDependency axis) {
    if (axis == AxisDependency.LEFT)
      return axisLeft.axisRange;
    else
      return axisRight.axisRange;
  }

  MPPointD getValuesByTouchPoint(double x, double y, AxisDependency axis) {
    MPPointD result = MPPointD.getInstance1(0, 0);
    _getValuesByTouchPoint(x, y, axis, result);
    return result;
  }

  void _getValuesByTouchPoint(
      double x, double y, AxisDependency axis, MPPointD outputPoint) {
    painter?.getTransformer(axis)?.getValuesByTouchPoint2(x, y, outputPoint);
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
  void setVisibleYRange(
      double minYRange, double maxYRange, AxisDependency axis) {
    double minScale = getAxisRange(axis) / minYRange;
    double maxScale = getAxisRange(axis) / maxYRange;
    viewPortHandler.setMinMaxScaleY(minScale, maxScale);
  }
}

class UpdateListener implements AnimatorUpdateListener {
  final UpdateFunction _updateFunction;

  UpdateListener(this._updateFunction);

  @override
  void onAnimationUpdate(double x, double y) {
    _updateFunction(x, y);
  }

  @override
  void onRotateUpdate(double angle) {}
}

typedef UpdateFunction = void Function(double x, double y);
