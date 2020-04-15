import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/bar_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/highlight/horizontal_bar_highlighter.dart';
import 'package:mp_chart/mp/core/legend/legend.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/render/horizontal_bar_chart_renderer.dart';
import 'package:mp_chart/mp/core/render/legend_renderer.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer.dart';
import 'package:mp_chart/mp/core/chart_trans_listener.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/bar_chart_painter.dart';

class HorizontalBarChartPainter extends BarChartPainter {
  HorizontalBarChartPainter(
      BarData data,
      Animator animator,
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
      Color infoBgColor,
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
      Paint backgroundPaint,
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
      bool highlightFullBarEnabled,
      bool drawValueAboveBar,
      bool drawBarShadow,
      bool fitBars,
      ChartTransListener chartTransListener)
      : super(
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
            infoBgColor,
            infoPainter,
            descPainter,
            xAxis,
            legend,
            legendRenderer,
            rendererSettingFunction,
            selectedListener,
            maxVisibleCount,
            autoScaleMinMaxEnabled,
            pinchZoomEnabled,
            doubleTapToZoomEnabled,
            highlightPerDragEnabled,
            dragXEnabled,
            dragYEnabled,
            scaleXEnabled,
            scaleYEnabled,
            gridBackgroundPaint,
            backgroundPaint,
            borderPaint,
            drawGridBackground,
            drawBorders,
            clipValuesToContent,
            minOffset,
            keepPositionOnRotation,
            drawListener,
            axisLeft,
            axisRight,
            axisRendererLeft,
            axisRendererRight,
            leftAxisTransformer,
            rightAxisTransformer,
            xAxisRenderer,
            zoomMatrixBuffer,
            customViewPortEnabled,
            highlightFullBarEnabled,
            drawValueAboveBar,
            drawBarShadow,
            fitBars,
            chartTransListener);

  @override
  void initDefaultWithData() {
    super.initDefaultWithData();
    highlighter = HorizontalBarHighlighter(this);
    renderer = HorizontalBarChartRenderer(this, animator, viewPortHandler);
  }

  Rect _offsetsBuffer = Rect.zero;

  @override
  void calculateOffsets() {
    if (legend != null) legendRenderer.computeLegend(getBarData());
    renderer?.initBuffers();
    calcMinMax();

    double offsetLeft = 0, offsetRight = 0, offsetTop = 0, offsetBottom = 0;

    calculateLegendOffsets(_offsetsBuffer);

    offsetLeft += _offsetsBuffer.left;
    offsetTop += _offsetsBuffer.top;
    offsetRight += _offsetsBuffer.right;
    offsetBottom += _offsetsBuffer.bottom;

    // offsets for y-labels
    if (axisLeft.needsOffset()) {
      offsetTop +=
          axisLeft.getRequiredHeightSpace(axisRendererLeft.axisLabelPaint);
    }

    if (axisRight.needsOffset()) {
      offsetBottom +=
          axisRight.getRequiredHeightSpace(axisRendererRight.axisLabelPaint);
    }

    double xlabelwidth = xAxis.labelRotatedWidth.toDouble();

    if (xAxis.enabled) {
      // offsets for x-labels
      if (xAxis.position == XAxisPosition.BOTTOM) {
        offsetLeft += xlabelwidth;
      } else if (xAxis.position == XAxisPosition.TOP) {
        offsetRight += xlabelwidth;
      } else if (xAxis.position == XAxisPosition.BOTH_SIDED) {
        offsetLeft += xlabelwidth;
        offsetRight += xlabelwidth;
      }
    }

    offsetTop += extraTopOffset;
    offsetRight += extraRightOffset;
    offsetBottom += extraBottomOffset;
    offsetLeft += extraLeftOffset;

    double offset = Utils.convertDpToPixel(minOffset);

    viewPortHandler.restrainViewPort(
        max(offset, offsetLeft),
        max(offset, offsetTop),
        max(offset, offsetRight),
        max(offset, offsetBottom));

    prepareOffsetMatrix();
    prepareValuePxMatrix();
  }

  @override
  void prepareValuePxMatrix() {
    rightAxisTransformer.prepareMatrixValuePx(axisRight.axisMinimum,
        axisRight.axisRange, xAxis.axisRange, xAxis.axisMinimum);
    leftAxisTransformer.prepareMatrixValuePx(axisLeft.axisMinimum,
        axisLeft.axisRange, xAxis.axisRange, xAxis.axisMinimum);
  }

  @override
  List<double> getMarkerPosition(Highlight high) {
    return new List()..add(high.drawY)..add(high.drawX);
  }

  @override
  Rect getBarBounds(BarEntry e) {
    Rect bounds = Rect.zero;
    IBarDataSet set = getBarData().getDataSetForEntry(e);

    if (set == null) {
      bounds = Rect.fromLTRB(double.minPositive, double.minPositive,
          double.minPositive, double.minPositive);
      return bounds;
    }

    double y = e.y;
    double x = e.x;

    double barWidth = getBarData().barWidth;

    double top = x - barWidth / 2;
    double bottom = x + barWidth / 2;
    double left = y >= 0 ? y : 0;
    double right = y <= 0 ? y : 0;

    bounds = Rect.fromLTRB(left, top, right, bottom);

    return getTransformer(set.getAxisDependency()).rectValueToPixel(bounds);
  }

  List<double> mGetPositionBuffer = List(2);

  /// Returns a recyclable MPPointF instance.
  ///
  /// @param e
  /// @param axis
  /// @return
  @override
  MPPointF getPosition(Entry e, AxisDependency axis) {
    if (e == null) return null;

    List<double> vals = mGetPositionBuffer;
    vals[0] = e.y;
    vals[1] = e.x;

    getTransformer(axis).pointValuesToPixel(vals);

    return MPPointF.getInstance1(vals[0], vals[1]);
  }

  /// Returns the Highlight object (contains x-index and DataSet index) of the selected value at the given touch point
  /// inside the BarChart.
  ///
  /// @param x
  /// @param y
  /// @return
  @override
  Highlight getHighlightByTouchPoint(double x, double y) {
    if (getBarData() != null) {
      return highlighter.getHighlight(y, x); // switch x and y
    }
    return null;
  }

  @override
  double getLowestVisibleX() {
    getTransformer(AxisDependency.LEFT).getValuesByTouchPoint2(
        viewPortHandler.contentLeft(),
        viewPortHandler.contentBottom(),
        posForGetLowestVisibleX);
    double result = max(xAxis.axisMinimum, posForGetLowestVisibleX.y);
    return result;
  }

  @override
  double getHighestVisibleX() {
    getTransformer(AxisDependency.LEFT).getValuesByTouchPoint2(
        viewPortHandler.contentLeft(),
        viewPortHandler.contentTop(),
        posForGetHighestVisibleX);
    double result = min(xAxis.axisMaximum, posForGetHighestVisibleX.y);
    return result;
  }

  /// ###### VIEWPORT METHODS BELOW THIS ######

//  void setVisibleXRangeMaximum(double maxXRange) {
//    double xScale = xAxis.mAxisRange / (maxXRange);
//    viewPortHandler.setMinimumScaleY(xScale);
//  }
//
//  void setVisibleXRangeMinimum(double minXRange) {
//    double xScale = xAxis.mAxisRange / (minXRange);
//    viewPortHandler.setMaximumScaleY(xScale);
//  }
//
//  void setVisibleXRange(double minXRange, double maxXRange) {
//    double minScale = xAxis.mAxisRange / minXRange;
//    double maxScale = xAxis.mAxisRange / maxXRange;
//    viewPortHandler.setMinMaxScaleY(minScale, maxScale);
//  }

  @override
  void setVisibleYRangeMaximum(double maxYRange, AxisDependency axis) {
    double yScale = getAxisRange(axis) / maxYRange;
    viewPortHandler.setMinimumScaleX(yScale);
  }

  @override
  void setVisibleYRangeMinimum(double minYRange, AxisDependency axis) {
    double yScale = getAxisRange(axis) / minYRange;
    viewPortHandler.setMaximumScaleX(yScale);
  }

  @override
  void setVisibleYRange(
      double minYRange, double maxYRange, AxisDependency axis) {
    double minScale = getAxisRange(axis) / minYRange;
    double maxScale = getAxisRange(axis) / maxYRange;
    viewPortHandler.setMinMaxScaleX(minScale, maxScale);
  }
}
