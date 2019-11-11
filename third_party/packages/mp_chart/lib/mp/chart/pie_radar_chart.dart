import 'package:flutter/widgets.dart';
import 'package:mp_chart/mp/chart/chart.dart';
import 'package:mp_chart/mp/controller/pie_radar_controller.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/highlight_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

abstract class PieRadarChart<C extends PieRadarController> extends Chart<C> {
  const PieRadarChart(C controller) : super(controller);
}

abstract class PieRadarChartState<T extends PieRadarChart>
    extends ChartState<T> {
  Highlight lastHighlighted;
  MPPointF _touchStartPoint = MPPointF.getInstance1(0, 0);
  double _startAngle = 0.0;

  void _setGestureStartAngle(double x, double y) {
    _startAngle = widget.controller.painter.getAngleForPoint(x, y) -
        widget.controller.painter.getRawRotationAngle();
  }

  void _updateGestureRotation(double x, double y) {
    double angle =
        widget.controller.painter.getAngleForPoint(x, y) - _startAngle;
    widget.controller.rawRotationAngle = angle;
    widget.controller.rotationAngle =
        Utils.getNormalizedAngle(widget.controller.rawRotationAngle);
  }

  @override
  void onDoubleTap() {}

  @override
  void onScaleEnd(ScaleEndDetails detail) {}

  @override
  void onScaleStart(ScaleStartDetails detail) {
    _setGestureStartAngle(detail.localFocalPoint.dx, detail.localFocalPoint.dy);
    _touchStartPoint
      ..x = detail.localFocalPoint.dx
      ..y = detail.localFocalPoint.dy;
  }

  @override
  void onScaleUpdate(ScaleUpdateDetails detail) {
    _updateGestureRotation(
        detail.localFocalPoint.dx, detail.localFocalPoint.dy);
    setStateIfNotDispose();
  }

  @override
  void onSingleTapUp(TapUpDetails detail) {
    if (widget.controller.painter.highLightPerTapEnabled) {
      Highlight h = widget.controller.painter.getHighlightByTouchPoint(
          detail.localPosition.dx, detail.localPosition.dy);
      lastHighlighted = HighlightUtils.performHighlight(
          widget.controller.painter, h, lastHighlighted);
      setStateIfNotDispose();
    } else {
      lastHighlighted = null;
    }
  }

  @override
  void onTapDown(TapDownDetails detail) {}

  @override
  void updatePainter() {
    if (widget.controller.painter.getData() != null &&
        widget.controller.painter.getData().dataSets != null &&
        widget.controller.painter.getData().dataSets.length > 0)
      widget.controller.painter.highlightValue6(lastHighlighted, false);
  }
}
