import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/chart/pie_chart.dart';
import 'package:mp_chart/mp/controller/pie_radar_controller.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/data/pie_data.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/marker/bar_chart_marker.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/painter/pie_chart_painter.dart';

class PieChartController extends PieRadarController<PieChartPainter> {
  bool drawEntryLabels;
  bool drawHole;
  bool drawSlicesUnderHole;
  bool usePercentValues;
  bool drawRoundedSlices;
  String centerText;
  double holeRadiusPercent; // = 50
  double transparentCircleRadiusPercent; //= 55
  bool drawCenterText; // = true
  double centerTextRadiusPercent; // = 100.0
  double maxAngle; // = 360
  double minAngleForSlices; // = 0
  double centerTextOffsetX;
  double centerTextOffsetY;
  TypeFace centerTextTypeface;
  TypeFace entryLabelTypeface;
  Color backgroundColor;

  PieChartController({
    this.drawEntryLabels = true,
    this.drawHole = true,
    this.drawSlicesUnderHole = false,
    this.usePercentValues = false,
    this.drawRoundedSlices = false,
    this.centerText = "",
    this.holeRadiusPercent = 50.0,
    this.transparentCircleRadiusPercent = 55.0,
    this.drawCenterText = true,
    this.centerTextRadiusPercent = 100.0,
    this.maxAngle = 360,
    this.minAngleForSlices = 0,
    this.centerTextOffsetX = 0.0,
    this.centerTextOffsetY = 0.0,
    this.centerTextTypeface,
    this.entryLabelTypeface,
    this.backgroundColor,
    IMarker marker,
    Description description,
    XAxisSettingFunction xAxisSettingFunction,
    LegendSettingFunction legendSettingFunction,
    DataRendererSettingFunction rendererSettingFunction,
    OnChartValueSelectedListener selectionListener,
    double rotationAngle = 270,
    double rawRotationAngle = 270,
    bool rotateEnabled = true,
    double minOffset = 30.0,
    String noDataText = "No chart data available.",
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
            noDataText: noDataText,
            xAxisSettingFunction: xAxisSettingFunction,
            legendSettingFunction: legendSettingFunction,
            rendererSettingFunction: rendererSettingFunction,
            description: description,
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
            rotationAngle: rotationAngle,
            rawRotationAngle: rawRotationAngle,
            rotateEnabled: rotateEnabled,
            minOffset: minOffset);

  @override
  IMarker initMarker() => BarChartMarker();

  PieData get data => super.data;

  PieChartPainter get painter => super.painter;

  PieChartState get state => super.state;

  @override
  void initialPainter() {
    painter = PieChartPainter(
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
      rotationAngle,
      rawRotationAngle,
      rotateEnabled,
      minOffset,
      drawEntryLabels,
      drawHole,
      drawSlicesUnderHole,
      usePercentValues,
      drawRoundedSlices,
      centerText,
      centerTextOffsetX,
      centerTextOffsetY,
      entryLabelTypeface,
      centerTextTypeface,
      holeRadiusPercent,
      transparentCircleRadiusPercent,
      drawCenterText,
      centerTextRadiusPercent,
      maxAngle,
      minAngleForSlices,
      backgroundColor,
    );
  }

  @override
  PieChartState createRealState() {
    return PieChartState();
  }
}
