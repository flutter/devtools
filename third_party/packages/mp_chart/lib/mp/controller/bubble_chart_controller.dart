import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:mp_chart/mp/chart/bubble_chart.dart';
import 'package:mp_chart/mp/controller/bar_line_scatter_candle_bubble_controller.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/bubble_data.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/painter/bubble_chart_painter.dart';

class BubbleChartController
    extends BarLineScatterCandleBubbleController<BubbleChartPainter> {
  BubbleChartController({
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
            gridBackColor: gridBackColor,
            borderColor: borderColor,
            borderStrokeWidth: borderStrokeWidth,
            axisLeftSettingFunction: axisLeftSettingFunction,
            axisRightSettingFunction: axisRightSettingFunction);

  BubbleData get data => super.data;

  BubbleChartState get state => super.state;

  BubbleChartPainter get painter => super.painter;

  @override
  void initialPainter() {
    painter = BubbleChartPainter(
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
        customViewPortEnabled);
  }

  @override
  BubbleChartState createRealState() {
    return BubbleChartState();
  }
}
