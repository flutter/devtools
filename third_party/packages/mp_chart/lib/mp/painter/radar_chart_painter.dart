import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/radar_data.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/highlight/radar_highlighter.dart';
import 'package:mp_chart/mp/core/legend/legend.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/render/legend_renderer.dart';
import 'package:mp_chart/mp/core/render/radar_chart_renderer.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer_radar_chart.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer_radar_chart.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/pie_redar_chart_painter.dart';

class RadarChartPainter extends PieRadarChartPainter<RadarData> {
  /// width of the main web lines
  final double _webLineWidth;

  /// width of the inner web lines
  final double _innerWebLineWidth;

  /// color for the main web lines
  final Color _webColor; // = Color.fromARGB(255, 122, 122, 122)

  /// color for the inner web
  final Color _webColorInner; // = Color.fromARGB(255, 122, 122, 122)

  /// transparency the grid is drawn with (0-255)
  final int _webAlpha;

  /// flag indicating if the web lines should be drawn or not
  final bool _drawWeb;

  /// modulus that determines how many labels and web-lines are skipped before the next is drawn
  final int _skipWebLineCount;

  /// the object reprsenting the y-axis labels
  final YAxis _yAxis;

  ////////////
  YAxisRendererRadarChart _yAxisRenderer;
  XAxisRendererRadarChart _xAxisRenderer;

  Color get webColor => _webColor;

  Color get webColorInner => _webColorInner;

  double get webLineWidth => _webLineWidth;

  double get innerWebLineWidth => _innerWebLineWidth;

  int get webAlpha => _webAlpha;

  int get skipWebLineCount => _skipWebLineCount;

  YAxis get yAxis => _yAxis;

  RadarChartPainter(
      RadarData data,
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
      double rotationAngle,
      double rawRotationAngle,
      bool rotateEnabled,
      double minOffset,
      double webLineWidth,
      double innerWebLineWidth,
      Color webColor,
      Color webColorInner,
      int webAlpha,
      bool drawWeb,
      int skipWebLineCount,
      YAxis yAxis,
      Color backgroundColor)
      : _webLineWidth = webLineWidth,
        _innerWebLineWidth = innerWebLineWidth,
        _webColor = webColor,
        _webColorInner = webColorInner,
        _webAlpha = webAlpha,
        _drawWeb = drawWeb,
        _skipWebLineCount = skipWebLineCount,
        _yAxis = yAxis,
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
          infoBgColor,
          infoPainter,
          descPainter,
          xAxis,
          legend,
          legendRenderer,
          rendererSettingFunction,
          selectedListener,
          rotationAngle,
          rawRotationAngle,
          rotateEnabled,
          minOffset,
          backgroundColor,
        );

  @override
  void initDefaultWithData() {
    super.initDefaultWithData();
    renderer = RadarChartRenderer(this, animator, viewPortHandler);
    highlighter = RadarHighlighter(this);
    _yAxisRenderer = YAxisRendererRadarChart(viewPortHandler, _yAxis, this);
    _xAxisRenderer = XAxisRendererRadarChart(viewPortHandler, xAxis, this);
  }

  @override
  void calcMinMax() {
    super.calcMinMax();
    _yAxis.calculate(getData().getYMin2(AxisDependency.LEFT),
        getData().getYMax2(AxisDependency.LEFT));
    xAxis.calculate(
        0, getData().getMaxEntryCountSet().getEntryCount().toDouble());
  }

  @override
  void calculateOffsets() {
    super.calculateOffsets();
    calcMinMax();
    _yAxisRenderer.computeAxis(
        _yAxis.axisMinimum, _yAxis.axisMaximum, _yAxis.inverted);
    _xAxisRenderer.computeAxis(xAxis.axisMinimum, xAxis.axisMaximum, false);
    if (legend != null && !legend.isLegendCustom)
      legendRenderer.computeLegend(getData());
  }

  @override
  void onPaint(Canvas canvas, Size size) {
    super.onPaint(canvas, size);
    if (xAxis.enabled)
      _xAxisRenderer.computeAxis(xAxis.axisMinimum, xAxis.axisMaximum, false);

    _xAxisRenderer.renderAxisLabels(canvas);

    if (_drawWeb) renderer.drawExtras(canvas);

    if (_yAxis.enabled && _yAxis.drawLimitLineBehindData)
      _yAxisRenderer.renderLimitLines(canvas);

    renderer.drawData(canvas);

    if (valuesToHighlight())
      renderer.drawHighlighted(canvas, indicesToHighlight);

    if (_yAxis.enabled && !_yAxis.drawLimitLineBehindData)
      _yAxisRenderer.renderLimitLines(canvas);

    _yAxisRenderer.renderAxisLabels(canvas);

    renderer.drawValues(canvas);

    legendRenderer.renderLegend(canvas);

    drawDescription(canvas, size);

    drawMarkers(canvas);
  }

  /// Returns the factor that is needed to transform values into pixels.
  ///
  /// @return
  double getFactor() {
    Rect content = viewPortHandler.getContentRect();
    return min(content.width / 2, content.height / 2) / _yAxis.axisRange;
  }

  /// Returns the angle that each slice in the radar chart occupies.
  ///
  /// @return
  double getSliceAngle() {
    return 360 / getData().getMaxEntryCountSet().getEntryCount();
  }

  @override
  int getIndexForAngle(double angle) {
    // take the current angle of the chart into consideration
    double a = Utils.getNormalizedAngle(angle - getRotationAngle());

    double sliceangle = getSliceAngle();

    int max = getData().getMaxEntryCountSet().getEntryCount();

    int index = 0;

    for (int i = 0; i < max; i++) {
      double referenceAngle = sliceangle * (i + 1) - sliceangle / 2;

      if (referenceAngle > a) {
        index = i;
        break;
      }
    }

    return index;
  }

  @override
  double getRequiredLegendOffset() {
    var size = legendRenderer.legendLabelPaint.text.style.fontSize;
    return (size == null ? Utils.convertDpToPixel(9) : size) * 4.0;
  }

  @override
  double getRequiredBaseOffset() {
    return xAxis.enabled && xAxis.drawLabels
        ? xAxis.labelRotatedWidth.toDouble()
        : Utils.convertDpToPixel(10);
  }

  @override
  double getRadius() {
    Rect content = viewPortHandler.getContentRect();
    return min(content.width / 2, content.height / 2);
  }

  /// Returns the maximum value this chart can display on it's y-axis.
  double getYChartMax() {
    return _yAxis.axisMaximum;
  }

  /// Returns the minimum value this chart can display on it's y-axis.
  double getYChartMin() {
    return _yAxis.axisMinimum;
  }
}
