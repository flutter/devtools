import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/controller/controller.dart';
import 'package:mp_chart/mp/core/common_interfaces.dart';
import 'package:mp_chart/mp/core/description.dart';
import 'package:mp_chart/mp/core/functions.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/painter/pie_redar_chart_painter.dart';

abstract class PieRadarController<P extends PieRadarChartPainter>
    extends Controller<P> {
  double rotationAngle;
  double rawRotationAngle;
  bool rotateEnabled;
  double minOffset;

  PieRadarController(
      {this.rotationAngle = 270,
      this.rawRotationAngle = 270,
      this.rotateEnabled = true,
      this.minOffset = 30,
      IMarker marker,
      Description description,
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
      String noDataText = "No chart data available.",
      XAxisSettingFunction xAxisSettingFunction,
      LegendSettingFunction legendSettingFunction,
      DataRendererSettingFunction rendererSettingFunction})
      : super(
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
            infoTextColor: infoTextColor);

  @override
  void onRotateUpdate(double angle) {
    rawRotationAngle = angle;
    rotationAngle = Utils.getNormalizedAngle(rawRotationAngle);
    state.setStateIfNotDispose();
  }

  P get painter => super.painter;
}
