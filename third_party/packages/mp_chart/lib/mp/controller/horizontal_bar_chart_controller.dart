import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:mp_chart/mp/controller/bar_chart_controller.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/marker/horizontal_bar_chart_marker.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer_horizontal_bar_chart.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer_horizontal_bar_chart.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/transformer/transformer_horizontal_bar_chart.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/horizontal_bar_chart_painter.dart';

class HorizontalBarChartController extends BarChartController {
  HorizontalBarChartController({
    bool highlightFullBarEnabled = true,
    bool drawValueAboveBar = false,
    bool drawBarShadow = false,
    bool fitBars = true,
    int maxVisibleCount = 100,
    bool autoScaleMinMaxEnabled = true,
    bool doubleTapToZoomEnabled = true,
    bool highlightPerDragEnabled = true,
    bool dragXEnabled = true,
    bool dragYEnabled = true,
    bool scaleXEnabled = true,
    bool scaleYEnabled = true,
    bool drawGridBackground = false,
    bool drawBorders = false,
    bool clipValuesToContent = false,
    double minOffset = 30.0,
    OnDrawListener drawListener,
    YAxis axisLeft,
    YAxis axisRight,
    YAxisRenderer axisRendererLeft,
    YAxisRenderer axisRendererRight,
    Transformer leftAxisTransformer,
    Transformer rightAxisTransformer,
    XAxisRenderer xAxisRenderer,
    bool customViewPortEnabled = false,
    Matrix4 zoomMatrixBuffer,
    bool pinchZoomEnabled = true,
    bool keepPositionOnRotation = false,
    Paint gridBackgroundPaint,
    Paint borderPaint,
    Color backgroundColor,
    Color gridBackColor,
    Color borderColor,
    double borderStrokeWidth = 1.0,
    AxisLeftSettingFunction axisLeftSettingFunction,
    AxisRightSettingFunction axisRightSettingFunction,
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
            highlightFullBarEnabled: highlightFullBarEnabled,
            drawValueAboveBar: drawValueAboveBar,
            drawBarShadow: drawBarShadow,
            fitBars: fitBars,
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
            infoTextColor: infoTextColor,
            maxVisibleCount: maxVisibleCount,
            autoScaleMinMaxEnabled: autoScaleMinMaxEnabled,
            doubleTapToZoomEnabled: doubleTapToZoomEnabled,
            highlightPerDragEnabled: highlightPerDragEnabled,
            dragXEnabled: dragXEnabled,
            dragYEnabled: dragYEnabled,
            scaleXEnabled: scaleXEnabled,
            scaleYEnabled: scaleYEnabled,
            drawGridBackground: drawGridBackground,
            drawBorders: drawBorders,
            clipValuesToContent: clipValuesToContent,
            minOffset: minOffset,
            drawListener: drawListener,
            axisLeft: axisLeft,
            axisRight: axisRight,
            axisRendererLeft: axisRendererLeft,
            axisRendererRight: axisRendererRight,
            leftAxisTransformer: leftAxisTransformer,
            rightAxisTransformer: rightAxisTransformer,
            xAxisRenderer: xAxisRenderer,
            customViewPortEnabled: customViewPortEnabled,
            zoomMatrixBuffer: zoomMatrixBuffer,
            pinchZoomEnabled: pinchZoomEnabled,
            keepPositionOnRotation: keepPositionOnRotation,
            gridBackgroundPaint: gridBackgroundPaint,
            borderPaint: borderPaint,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            gridBackColor: gridBackColor,
            borderStrokeWidth: borderStrokeWidth,
            axisLeftSettingFunction: axisLeftSettingFunction,
            axisRightSettingFunction: axisRightSettingFunction);

  HorizontalBarChartPainter get painter => super.painter;

  @override
  void initialPainter() {
    painter = HorizontalBarChartPainter(
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
        description,
        drawMarkers,
        infoPaint,
        descPaint,
        xAxis,
        legend,
        legendRenderer,
        rendererSettingFunction,
        selectionListener,
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
        fitBars);
  }

  @override
  IMarker initMarker() => HorizontalBarChartMarker();

  @override
  Transformer initLeftAxisTransformer() =>
      TransformerHorizontalBarChart(viewPortHandler);

  @override
  Transformer initRightAxisTransformer() =>
      TransformerHorizontalBarChart(viewPortHandler);

  @override
  YAxisRenderer initAxisRendererLeft() => YAxisRendererHorizontalBarChart(
      viewPortHandler, axisLeft, leftAxisTransformer);

  @override
  YAxisRenderer initAxisRendererRight() => YAxisRendererHorizontalBarChart(
      viewPortHandler, axisRight, rightAxisTransformer);

  @override
  XAxisRenderer initXAxisRenderer() => XAxisRendererHorizontalBarChart(
      viewPortHandler, xAxis, leftAxisTransformer);

  @override
  ViewPortHandler initViewPortHandler() => HorizontalViewPortHandler();

  @override
  void setVisibleXRangeMaximum(double maxXRange) {
    double xScale = xAxis.axisRange / (maxXRange);
    viewPortHandler.setMinimumScaleY(xScale);
  }

  @override
  void setVisibleXRangeMinimum(double minXRange) {
    double xScale = xAxis.axisRange / (minXRange);
    viewPortHandler.setMaximumScaleY(xScale);
  }

  @override
  void setVisibleXRange(double minXRange, double maxXRange) {
    double minScale = xAxis.axisRange / minXRange;
    double maxScale = xAxis.axisRange / maxXRange;
    viewPortHandler.setMinMaxScaleY(minScale, maxScale);
  }

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
